namespace :brevo do
  desc "Reconcile Consul member accounts with the Brevo member list"
  task sync_members: :environment do
    # Silent no-op where the integration is not set up, so the nightly cron does not leave a failed
    # run behind on every installation that has no Brevo secrets. A manual sync from /adm reports
    # the missing configuration instead, because there somebody is waiting for an answer.
    unless Brevo::Settings.sync_enabled?
      ApplicationLogger.new.info "Brevo member sync is not configured, skipping"
      next
    end

    ApplicationLogger.new.info "Reconciling members with the Brevo member list"
    log = Brevo::MemberSync.call

    ApplicationLogger.new.info(
      "Brevo member sync #{log.status}: #{log.contacts_count} contacts, " \
      "#{log.created_count} created, #{log.erased_count} erased, " \
      "#{log.skipped_count} unchanged, #{log.failed_count} failed"
    )
  end
end
