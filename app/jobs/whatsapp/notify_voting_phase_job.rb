class Whatsapp::NotifyVotingPhaseJob < ApplicationJob
  queue_as :default
  queue_with_priority ::Whatsapp::BULK_PRIORITY

  # The two pushes about a vote: one when it opens, one a few days before it
  # closes. Both carry the action rather than describing it — the template's own
  # button, because a notification is an approved template and a button added at
  # send time is not part of what Meta approved.
  #
  # Separate from Whatsapp::NotifyPhaseDeadlineJob rather than a third phase type
  # in it. That job's audience is a phase the bot can take a submission into, and
  # it gates on #selectable_by_users? and #whatsapp_submissions_enabled? — neither
  # of which a voting phase answers: the first is not defined for it and the second
  # is false for every phase without a drafting flow. What decides here is whether
  # the phase has a published ballot at all.
  #
  # Idempotent by construction, the same way the deadline job is: every recipient
  # is claimed in Whatsapp::NotificationDelivery before the send, so a retry, a
  # redeploy or a second run on the same day cannot push the same reminder twice.
  DAYS_BEFORE_DEADLINE = 3
  BATCH_SIZE = 50

  def perform
    return if !::Whatsapp.enabled?

    notify(phases_starting_on(Date.current), "voting_started")
    notify(phases_ending_on(DAYS_BEFORE_DEADLINE.days.from_now.to_date), "voting_ending")
  end

  private

    # A phase with no start date never announces its opening: there is no day to
    # anchor the push to, and every following day would be as good a candidate.
    def phases_starting_on(date)
      voting_phases.where(start_date: date)
    end

    def phases_ending_on(date)
      voting_phases.where(end_date: date)
    end

    def voting_phases
      ::ProjektPhase
        .where(type: ::ProjektPhase::VotingPhase.name)
        .includes(:settings, projekt: :page)
    end

    def notify(projekt_phases, kind)
      projekt_phases.find_each do |projekt_phase|
        next if !::Whatsapp::EligiblePhasesQuery.projekt_visible?(projekt_phase.projekt)
        next if !projekt_phase.current?

        notify_phase(projekt_phase, kind)
      end
    end

    # Which of the phase's three templates goes out is decided once per phase and
    # never per recipient: whether the chat can carry this poll to the end is a
    # property of the poll, and asking it per account would ask it once per number.
    #
    # Nothing is pushed for a phase with no published ballot. The link would open a
    # page listing no vote, and the button would offer one that does not exist yet.
    def notify_phase(projekt_phase, kind)
      votable_poll = ::Whatsapp::VotableBallotQuery.for(projekt_phase)
      poll = votable_poll || ::Polls::PhaseBallotQuery.for(projekt_phase)

      return if poll.blank?

      variant = ::Whatsapp::NotificationTemplates.voting_variant(
        kind, votable: votable_poll.present?
      )

      return if variant.blank?

      audience.find_each(batch_size: BATCH_SIZE) do |account|
        deliver(account, projekt_phase, kind, variant, poll)
      end
    end

    # The deadline subscription, for both pushes. A vote that has opened and one
    # about to close are the same promise to the citizen who switched it on — that
    # they hear when something they can still act on is running — and WhatsApp's
    # ten-row settings list has no room for a type per phase kind.
    def audience
      ::Whatsapp::Account.subscribed_to(:deadline_approaching)
    end

    # Claimed under the kind rather than the variant: which template carried the
    # push is the portal's business, whereas "this account has been told about this
    # phase" is the citizen's, and an approval landing between two runs must not
    # buy them a second copy.
    def deliver(account, projekt_phase, kind, variant, poll)
      claimed = ::Whatsapp::NotificationDelivery.claim(
        account_id: account.id, projekt_phase_id: projekt_phase.id, kind: kind
      )

      return if !claimed

      send_variant(account, projekt_phase, variant, poll)
    end

    def send_variant(account, projekt_phase, variant, poll)
      name = ::Whatsapp::NotificationTemplates.name_for(variant)

      case ::Whatsapp::NotificationTemplates.shape(variant)
      when ::Whatsapp::NotificationTemplates::ACTION_SHAPE
        send_action(account, projekt_phase, name)
      when ::Whatsapp::NotificationTemplates::LINK_SHAPE
        send_link(account, projekt_phase, name, poll)
      else
        send_body(account, projekt_phase, name, poll)
      end
    end

    # The payload is the pill the projekt card already carries, so the tap lands in
    # the one place that decides between voting here and handing over — and it is
    # re-resolved and re-checked there, because a template button sits in a chat
    # history for as long as the chat does.
    def send_action(account, projekt_phase, name)
      ::Whatsapp::Send.reply_button_template(
        account: account,
        name: name,
        payload: ::Whatsapp::FlowActions.id_for(action: :phase_open, param: projekt_phase.id),
        projekt_id: projekt_phase.projekt_id
      )
    end

    def send_link(account, projekt_phase, name, poll)
      ::Whatsapp::Send.link_button_template(
        account: account,
        name: name,
        button_variable: poll.id,
        projekt_id: projekt_phase.projekt_id
      )
    end

    def send_body(account, projekt_phase, name, poll)
      ::Whatsapp::Send.template(
        account: account,
        name: name,
        variables: [::Whatsapp::ProjektLink.poll_ballot_url(poll)],
        projekt_id: projekt_phase.projekt_id
      )
    end
end
