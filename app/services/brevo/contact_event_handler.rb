class Brevo::ContactEventHandler < ApplicationService
  # Handles one webhook event so a member added or removed in Brevo lands here within seconds
  # instead of at the next nightly reconcile.
  #
  # The payload is never trusted on its own: every event is verified against the Brevo API before
  # anything happens, because the event only says something changed, not what the member list looks
  # like now. A stale or unrelated event therefore costs a read and nothing else.
  #
  # `unsubscribed` is deliberately not a removal. Withdrawing marketing consent is not leaving the
  # association, and treating it as one would erase accounts over a newsletter opt-out.
  #
  # Brevo spells the same event two ways: a webhook is registered for "listAddition" but the payload
  # arrives as "list_addition". Every name is therefore compared in a normalized form, so both
  # spellings — and anything Brevo renames later in the same style — match.
  ADDITION_EVENTS = %w[listaddition contactadded contactcreated].freeze
  REMOVAL_EVENTS = %w[contactdeleted listremoval contactremovedfromlist].freeze

  # Leaving the member list without leaving Brevo arrives as contact_updated — the same event a
  # changed phone number produces. Which one it is can be read off the payload, so an update that
  # leaves the member list alone is dropped before it reaches the queue instead of costing an API
  # read and a log row per bounce and per edited attribute in the whole Brevo account.
  UPDATE_EVENTS = %w[contactupdated].freeze

  def initialize(payload)
    @payload = payload || {}
  end

  def call
    return unless relevant_event?
    return unless Brevo::Settings.sync_enabled?

    log = BrevoSyncLog.start!(source: "webhook")

    if targets.empty?
      log.record(action: "failed", message: "The event identified no contact")
    else
      targets.each { |address| addition? ? handle_addition(log, address) : handle_removal(log, address) }
    end

    log.finish!(status: log.failed_count.positive? ? "failed" : "completed")
    log
  rescue StandardError => e
    Sentry.capture_exception(e)
    Rails.logger.error("[Brevo] webhook event failed: #{e.class} (#{e.message})")
    # Not re-raised: the nightly reconcile is the backstop for anything a webhook misses, and
    # retrying a spent event would only pile up failed rows.
    log&.fail!("#{e.class}: #{e.message}")

    log
  end

  def self.relevant_event?(payload)
    event = normalize_event(payload)
    return true if ADDITION_EVENTS.include?(event) || REMOVAL_EVENTS.include?(event)
    return false unless UPDATE_EVENTS.include?(event)

    member_list_change(payload).present?
  end

  def self.normalize_event(payload)
    payload.to_h["event"].to_s.downcase.delete("_-")
  end

  # Which side of the member list an update touched, or nil when it touched neither. Being told the
  # list only decides whether to look — membership itself is still read back from Brevo before an
  # account is created or erased, so a payload cannot talk this into anything on its own.
  def self.member_list_change(payload)
    changes = Array(payload.to_h["content"]).filter_map { |entry| entry.to_h["list"] }

    return :addition if changes.any? { |change| member_list?(change["addition"]) }
    return :removal if changes.any? { |change| member_list?(change["deletion"]) }

    nil
  end

  def self.member_list?(lists)
    Array(lists).any? { |list| list.to_h["id"].to_s == Brevo::Settings.member_list_id.to_s }
  end

  private

    def handle_addition(log, email)
      contact = contact_for(email)

      unless in_member_list?(contact)
        log.skipped_count += 1
        return log.record(action: "linked", email: email, contact_id: contact&.dig("id"),
                          message: "Ignored: the contact is not in the configured member list")
      end

      record_provisioning(log, contact)
    end

    def record_provisioning(log, contact)
      email = contact["email"]
      contact_id = contact["id"]
      result = Brevo::MemberProvisioner.call(contact)

      if !result.success?
        log.record(action: "failed", email: email, contact_id: contact_id, message: result.error.to_s)
      elsif result.created?
        log.created_count += 1
        log.record(action: "created", email: email, contact_id: contact_id)
      else
        log.skipped_count += 1
        log.record(action: "linked", email: email, contact_id: contact_id,
                   message: "Existing account linked to the Brevo contact")
      end
    end

    def handle_removal(log, email)
      contact = contact_for(email)
      contact_id = contact&.dig("id") || payload_contact_id

      if in_member_list?(contact)
        log.skipped_count += 1
        return log.record(action: "linked", email: email, contact_id: contact_id,
                          message: "Ignored: the contact is still in the member list")
      end

      user = user_for_removal(email, contact_id)

      if user.blank?
        log.skipped_count += 1
        return log.record(action: "linked", email: email, contact_id: contact_id,
                          message: "Ignored: no account is linked to this contact")
      end

      record_revocation(log, user, contact_id)
    end

    def record_revocation(log, user, contact_id)
      result = Brevo::MemberRevoker.call(user, reason: erase_reason)

      if result.erased?
        log.erased_count += 1
        log.record(action: "erased", email: result.email, contact_id: contact_id,
                   message: "Contact was removed from the Brevo member list")
      else
        log.skipped_count += 1
        log.record(action: "linked", email: result.email, contact_id: contact_id,
                   message: "Left untouched (#{result.skipped_reason})")
      end
    end

    def user_for_removal(email, contact_id)
      by_contact = User.find_by(brevo_contact_id: contact_id) if contact_id.present?
      return by_contact if by_contact.present?
      return if email.blank?

      User.brevo_members.find_by("LOWER(email) = ?", email)
    end

    # One event can name several contacts: a bulk deletion in Brevo arrives as a single
    # contact_deleted whose "email" is an array of every address it removed, and each of them has to
    # be answered for. A nil target is an event that carried an id but no address.
    def targets
      @targets ||= emails.presence || (payload_contact_id.present? ? [nil] : [])
    end

    def emails
      @emails ||= Array(@payload["email"] || @payload.dig("contact", "email"))
                  .map { |value| value.to_s.strip.downcase.presence }.compact.uniq
    end

    # Reads the contact back from Brevo; nil means Brevo no longer knows it, which is itself the
    # answer for a deletion event. Cached per address, because a removal asks twice.
    def contact_for(email)
      @contacts ||= {}
      return @contacts[email] if @contacts.key?(email)

      @contacts[email] = Brevo::ApiClient.new.contact(email.presence || payload_contact_id)
    end

    def in_member_list?(contact)
      return false if contact.blank?

      Array(contact["listIds"]).map(&:to_s).include?(Brevo::Settings.member_list_id.to_s)
    end

    def relevant_event?
      self.class.relevant_event?(@payload)
    end

    def addition?
      event = self.class.normalize_event(@payload)
      return true if ADDITION_EVENTS.include?(event)
      return false if REMOVAL_EVENTS.include?(event)

      self.class.member_list_change(@payload) == :addition
    end

    # `id` in a Brevo payload is the id of the webhook, not of the contact — the events Brevo sends
    # carry no contact id at all. So a contact is looked up by the address the event names, and its
    # real id is taken from what Brevo answers.
    def payload_contact_id
      @payload["contact_id"] || @payload.dig("contact", "id")
    end

    def erase_reason
      "Brevo-Mitgliedersynchronisation: Kontakt aus der Mitgliederliste entfernt"
    end
end
