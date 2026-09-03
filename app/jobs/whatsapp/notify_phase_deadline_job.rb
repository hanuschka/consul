class Whatsapp::NotifyPhaseDeadlineJob < ApplicationJob
  queue_as :default
  queue_with_priority ::Whatsapp::BULK_PRIORITY

  # Catalog B10 and B11. Runs daily and asks the same question twice: which
  # proposal phases end soon, and which ended yesterday.
  #
  # Idempotent by construction — every recipient is claimed in
  # Whatsapp::NotificationDelivery before the send, so a retry, a redeploy or a
  # second run on the same day cannot push the same reminder twice. That matters
  # more here than anywhere else in the bot: a duplicated deadline reminder is
  # the kind of thing that gets a number reported.
  DAYS_BEFORE_DEADLINE = 3
  BATCH_SIZE = 50

  def perform
    return if !::Whatsapp.enabled?

    notify(phases_ending_on(DAYS_BEFORE_DEADLINE.days.from_now.to_date), "deadline_approaching")
    notify(phases_ending_on(Date.yesterday), "deadline_passed")
  end

  private

    # Only the phase types the bot has a submission flow for: a reminder to take
    # part in something the bot cannot take part in is noise.
    def phases_ending_on(date)
      ProjektPhase
        .where(type: Whatsapp::EligiblePhasesQuery::PHASE_CLASSES.map(&:name))
        .where(end_date: date)
        .includes(projekt: :page)
    end

    def notify(projekt_phases, kind)
      return if !Whatsapp::NotificationTemplates.configured?(kind)

      projekt_phases.find_each do |projekt_phase|
        next if !Whatsapp::EligiblePhasesQuery.projekt_visible?(projekt_phase.projekt)

        notify_phase(projekt_phase, kind)
      end
    end

    def notify_phase(projekt_phase, kind)
      url = Whatsapp::ProjektLink.phase_url(projekt_phase) ||
            Whatsapp::ProjektLink.url(projekt_phase.projekt)

      audience_for(kind).find_each(batch_size: BATCH_SIZE) do |account|
        deliver(account, projekt_phase, kind, url)
      end
    end

    def audience_for(kind)
      Whatsapp::Account.subscribed_to(notification_type_for(kind))
    end

    def notification_type_for(kind)
      kind == "deadline_approaching" ? :deadline_approaching : :deadline_passed
    end

    def deliver(account, projekt_phase, kind, url)
      claimed = Whatsapp::NotificationDelivery.claim(
        account_id: account.id, projekt_phase_id: projekt_phase.id, kind: kind
      )

      return if !claimed

      Whatsapp::Send.template(
        account: account,
        name: Whatsapp::NotificationTemplates.name_for(kind),
        variables: [url],
        projekt_id: projekt_phase.projekt_id
      )

      Whatsapp::NotificationFollowUp.phase_deadline(
        account: account, projekt_phase: projekt_phase, kind: kind
      )
    end
end
