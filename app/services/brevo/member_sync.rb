class Brevo::MemberSync < ApplicationService
  # Reconciles the Consul member accounts against the Brevo segment: contacts without an account
  # get one (AP3), accounts whose contact is gone are erased (AP4). Runs nightly, or on demand
  # from /adm, and always leaves a BrevoSyncLog behind.
  #
  # A contact that already maps to an account is a no-op. In particular an address changed in
  # Brevo does not rewrite the Consul login: the email is the credential here, and silently
  # repointing it from a marketing tool would lock people out of their own account.
  #
  # Deletions are the dangerous half, so they are bounded. An empty contact list — a wrong list id,
  # a partial API answer — must never be read as "every member left", and even a well-formed answer
  # that would erase most of the instance is refused and reported instead of executed.
  DELETION_SAFETY_RATIO = 0.5
  DELETION_SAFETY_FLOOR = 10

  def initialize(source: "scheduled", triggered_by: nil)
    @source = source
    @triggered_by = triggered_by
  end

  def call
    log = BrevoSyncLog.start!(source: @source, triggered_by: @triggered_by)

    unless Brevo::Settings.sync_enabled?
      log.fail!("Brevo member sync is not configured: api_key and member_list_id are required.")
      return log
    end

    contacts = client.contacts_in_list(Brevo::Settings.member_list_id)
    log.contacts_count = contacts.size
    log.save!

    provision_members(contacts, log)
    revoke_former_members(contacts, log)

    log.finish!(status: log.failed_count.positive? ? "failed" : "completed")
    log
  rescue StandardError => e
    Sentry.capture_exception(e)
    Rails.logger.error("[Brevo] member sync failed: #{e.class} (#{e.message})")
    log&.fail!("#{e.class}: #{e.message}")

    log
  end

  private

    def provision_members(contacts, log)
      linked_contact_ids = User.brevo_members.pluck(:brevo_contact_id).to_set

      contacts.each do |contact|
        if linked_contact_ids.include?(contact["id"])
          log.skipped_count += 1
          next
        end

        provision(contact, log)
      end

      log.save!
    end

    def provision(contact, log)
      email = contact["email"]

      if email.blank?
        log.record(action: "failed", contact_id: contact["id"], message: "Contact has no email address")
        return
      end

      result = Brevo::MemberProvisioner.call(contact)

      if !result.success?
        log.record(action: "failed", email: email, contact_id: contact["id"],
                   message: error_message_for(result))
      elsif result.created?
        log.created_count += 1
        log.record(action: "created", email: email, contact_id: contact["id"])
      else
        log.record(action: "linked", email: email, contact_id: contact["id"],
                   message: "Existing account linked to the Brevo contact")
      end
    end

    def revoke_former_members(contacts, log)
      contact_ids = contacts.filter_map { |contact| contact["id"] }

      if contact_ids.empty?
        log.record(action: "failed",
                   message: "Brevo returned no contacts for the configured list — " \
                            "no account was erased. Check the list id and the API key.")
        return log.save!
      end

      candidates = User.brevo_members.where.not(brevo_contact_id: contact_ids)
      return log.save! if refuse_mass_deletion?(candidates, log)

      candidates.each { |user| revoke(user, log) }

      log.save!
    end

    def revoke(user, log)
      contact_id = user.brevo_contact_id
      result = Brevo::MemberRevoker.call(user, reason: erase_reason)

      if result.erased?
        log.erased_count += 1
        log.record(action: "erased", email: result.email, contact_id: contact_id,
                   message: "Contact is no longer in the Brevo member list")
      elsif result.skipped_reason == :staff
        log.skipped_count += 1
        log.record(action: "linked", email: result.email, contact_id: contact_id,
                   message: "Left untouched: the account holds an admin or manager role")
      else
        log.skipped_count += 1
      end
    end

    def refuse_mass_deletion?(candidates, log)
      candidates_count = candidates.count
      return false if candidates_count <= DELETION_SAFETY_FLOOR

      members_count = User.brevo_members.count
      return false if candidates_count <= members_count * DELETION_SAFETY_RATIO

      log.record(action: "failed",
                 message: "Refused to erase #{candidates_count} of #{members_count} member " \
                          "accounts in one run. Nothing was erased — verify the Brevo list, " \
                          "then re-run the sync.")
      true
    end

    def error_message_for(result)
      return "A blocked account already uses this address" if result.error == :blocked_account

      result.error.to_s
    end

    def erase_reason
      "Brevo-Mitgliedersynchronisation: Kontakt nicht mehr in der Mitgliederliste"
    end

    def client
      @client ||= Brevo::ApiClient.new
    end
end
