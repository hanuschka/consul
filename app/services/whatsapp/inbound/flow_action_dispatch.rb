class Whatsapp::Inbound::FlowActionDispatch
  # One place every catalog pill lands. Actions that need an account are
  # refused here rather than in each service, so reading the portal never
  # dead-ends into "connect an account" and participating never silently
  # skips the check.
  #
  # Its gate sits after the recovery gate (the two tap-id namespaces share
  # nothing, but a retry pill must win) and before the text-less-audio halt —
  # a tap is never audio.

  # Making a submission, which a guest phase does allow: these need an
  # account only when the phase they point at does.
  # terms_accept belongs here and terms_decline deliberately does not: accepting
  # continues into the submission and needs whatever the phase needs, while
  # declining only says a sentence and opens the menu — gating that behind an
  # account would answer a citizen who just refused with a login request.
  # continue_flow and start_over split on the same line: carrying on returns to
  # the step that needs whatever the phase needs, while starting over only
  # discards and opens the menu.
  SUBMISSION_ACTIONS = %i[
    idea_start terms_accept category sentiment draft_publish draft_revise resume restart
    continue_flow
    image_upload image_generate image_skip location_share location_skip
    submit_final submit_anyway
  ].freeze

  # Supporting a proposal, reading your own submissions, changing
  # notification settings and unlinking all act on a Consul account, and a
  # guest has nothing to stand in for it with.
  #
  # my_contributions is here because the menu offers it to unlinked numbers
  # too: without the check it answers "you have not submitted anything yet" to
  # someone whose account is full of submissions, and never mentions that
  # linking is the missing part.
  ACCOUNT_ONLY_ACTIONS = %i[
    support support_instead support_prompt comment_prompt my_contributions
    notify_toggle notifications_done notifications_open
    unlink_confirm unlink_cancel unlink_start
  ].freeze

  # Which of them the citizen tapped, in the words the linking request uses to
  # name it. An action with no entry here is named by the generic reason —
  # every pill worth naming is one the citizen chose from a menu, and the rest
  # are mid-flow taps whose reason the message above them already gave.
  LINK_REQUEST_REASONS = {
    my_contributions: :contributions,
    notifications_open: :notifications,
    notify_toggle: :notifications,
    notifications_done: :notifications,
    support: :support,
    support_instead: :support,
    support_prompt: :support,
    comment_prompt: :comment
  }.freeze

  # Derived from the two groups rather than listed a third time. The union is
  # what account_required? gates on, so an action named in only one of the
  # source lists is still gated; written out by hand, an account-only pill
  # left out of the union would skip the check entirely and reach the flow
  # with no user behind it.
  ACCOUNT_ACTIONS = (SUBMISSION_ACTIONS + ACCOUNT_ONLY_ACTIONS).freeze

  GUEST_ELIGIBLE_ACTIONS = SUBMISSION_ACTIONS

  def initialize(conversation:, account:, reading:)
    @conversation = conversation
    @account = account
    @reading = reading
  end

  # True when the tap was one of the catalog's pills and was handled.
  def call
    flow_action = Whatsapp::FlowActions.parse(@reading.tapped_reply_id)

    return false if flow_action.blank?

    dispatch(flow_action[:action], flow_action[:param])

    true
  end

  private

    attr_reader :conversation, :account

    def inbound_message_id
      @reading.message_id
    end

    def dispatch(action, param)
      return request_link(action) if account_required?(action, param)

      case action
      when :link_yes, :link_retry
        Whatsapp::Flows::SendLoginLinkService.call(conversation:)
      when :link_switch
        Whatsapp::Flows::SendLoginLinkService.after_switch(conversation:)
      when :link_later
        Whatsapp::Flows::LinkOutcomeService.declined(conversation:)
      when :discover
        Whatsapp::Flows::BrowseProjektsService.call(conversation:)
      when :discover_category
        Whatsapp::Flows::BrowseProjektsService.category(conversation:, key: param)
      when :discover_public
        Whatsapp::Flows::DiscoveryService.unlinked(conversation:)
      when :submit_proposal
        Whatsapp::Flows::SubmitProposalService.call(conversation:)
      when :participate
        Whatsapp::Flows::ProjektParticipationService.ask_projekt(conversation:)
      when :participate_projekt
        offer_projekt_actions(param)
      when :view_projekt
        send_projekt_card(param)
      when :my_contributions
        Whatsapp::Flows::ContributionsService.call(conversation:)
      when :main_menu
        Whatsapp::Flows::MainMenuService.greeting(conversation:)
      when :support_prompt
        send_menu_prompt("whatsapp.bot.participation.prompts.support")
      when :comment_prompt
        send_menu_prompt("whatsapp.bot.participation.prompts.comment")
      when :notifications_open
        Whatsapp::Flows::NotificationSettingsService.call(conversation:)
      when :unlink_start
        Whatsapp::Flows::UnlinkService.ask(conversation:)
      when :dismiss
        decline("whatsapp.bot.declined.offer")
      when :unlink_cancel
        decline("whatsapp.bot.declined.unlink")
      when :unlink_confirm
        Whatsapp::Flows::UnlinkService.confirm(conversation:)
      when :notify_toggle
        Whatsapp::Flows::NotificationSettingsService.toggle(conversation:, type: param)
      when :notifications_done
        finish_notification_settings
      when :idea_start
        start_phase_flow(param)
      when :terms_accept
        Whatsapp::Flows::TermsConsentService.accept(conversation:)
      when :terms_decline
        Whatsapp::Flows::TermsConsentService.decline(conversation:)
      when :category
        Whatsapp::Flows::AskDraftChoiceService.assign_category(
          conversation:, label_id: param, inbound_message_id:
        )
      when :sentiment
        Whatsapp::Flows::AskDraftChoiceService.assign_sentiment(
          conversation:, sentiment_id: param, inbound_message_id:
        )
      when :draft_publish
        Whatsapp::Flows::ProposalImageService.ask(conversation:, inbound_message_id:)
      when :image_upload
        Whatsapp::Flows::ProposalImageService.ask_upload(conversation:)
      when :image_generate
        Whatsapp::Flows::ProposalImageService.generate(conversation:, inbound_message_id:)
      when :image_skip, :submit_final
        Whatsapp::Flows::AskLocationService.ask(conversation:, inbound_message_id:)
      when :location_share
        Whatsapp::Flows::AskLocationService.request(conversation:)
      when :location_skip
        Whatsapp::Flows::PublishResultService.call(conversation:, inbound_message_id:)
      when :draft_revise
        Whatsapp::Flows::AskRevisionService.ask(conversation:)
      when :submit_anyway
        Whatsapp::Flows::AskDuplicateChoiceService.submit_anyway(
          conversation:, inbound_message_id:
        )
      when :resume
        Whatsapp::Flows::ResumeOrRestartService.resume(conversation:)
      when :restart
        Whatsapp::Flows::ResumeOrRestartService.restart(conversation:)
      when :continue_flow
        Whatsapp::Flows::ContinueOrRestartService.continue(conversation:)
      when :start_over
        Whatsapp::Flows::ContinueOrRestartService.restart(conversation:)
      when :support
        Whatsapp::Flows::SupportService.register(conversation:, proposal_id: param)
      when :support_instead
        Whatsapp::Flows::AskDuplicateChoiceService.support_instead(
          conversation:, proposal_id: param
        )
      end
    end

    # Named rather than bare. The citizen chose something a moment ago, and a
    # login link on its own answers a question they did not ask — with no way
    # back to what they did (CON-2971).
    def request_link(action)
      Whatsapp::Flows::LinkRequestService.for_action(
        conversation:, reason: LINK_REQUEST_REASONS.fetch(action, :participation)
      )
    end

    def account_required?(action, param)
      return false if !ACCOUNT_ACTIONS.include?(action)
      return false if account.user.present?

      !guest_action?(action, param)
    end

    # Read from the phase the action points at rather than the conversation's:
    # idea_start carries its own phase id, and it is the tap that opens the flow
    # in the first place.
    # continue_flow is the one gated action that need not be about a submission
    # at all: it carries on whichever step was interrupted, and an unlinked
    # number reaches the participation listing — which needs no account — with
    # no phase chosen yet. Gated on the phase it does not have, "Weitermachen"
    # answered that citizen with a login request instead of the list they were
    # reading. Where a phase is set, the phase decides as it does for the rest.
    def guest_action?(action, param)
      return false if !GUEST_ELIGIBLE_ACTIONS.include?(action)
      return true if action == :continue_flow && conversation.projekt_phase.blank?

      target_phase_for(action, param)&.guest_participation?
    end

    def target_phase_for(action, param)
      return conversation.projekt_phase if action != :idea_start

      ::ProjektPhase.find_by(id: param)
    end

    # A tapped "no" is an answer, and it gets one back. Both of these did their
    # work and sent nothing, so the citizen could not tell whether the thing
    # they had just declined had happened anyway — which for unlinking is the
    # difference between an account that is still connected and one that is
    # not. The copy says what did *not* happen for exactly that reason.
    def decline(body_key)
      forget_offer

      send_phrase(body_key)
    end

    # Only when there is no submission work to lose. Reset unconditionally —
    # which is what both of these used to do — declining an offer that arrived
    # mid-submission threw the whole draft away: the assistant can put the
    # support question at any moment, so "Nein, danke" to it cost the citizen
    # everything they had written.
    #
    # Either way the step has to move. Skipping the write entirely stranded a
    # citizen who declined an unlink mid-draft: StepDispatch answers
    # AWAITING_UNLINK_CONFIRMATION by asking again, so every later message
    # re-put the question they had just said no to.
    def forget_offer
      return conversation.end_side_interaction! if conversation.unsaved_submission?

      conversation.reset_flow!
    end

    # A help row that names something the assistant resolves rather than a flow
    # the bot owns. It asks the question and stops: the citizen's next message
    # is free text, and the assistant's own tools find the proposal in it.
    def send_menu_prompt(body_key)
      conversation.reset_flow!

      send_phrase(body_key)
    end

    # The one send in this dispatcher. Three arms had written it out, which is
    # how the notification arm ended up being send_menu_prompt with a different
    # name.
    def send_phrase(body_key)
      Whatsapp::Send.text(
        account:,
        body: Whatsapp.phrase(body_key)
      )
    end

    def finish_notification_settings
      send_menu_prompt("whatsapp.bot.notifications.saved")
    end

    # The card on its own, for a citizen who wanted to look before deciding. No
    # flow is started and nothing is remembered: the submission button on the
    # card they were just sent is still there to come back to.
    def send_projekt_card(projekt_id)
      projekt = ::Projekt.find_by(id: projekt_id)

      return Whatsapp::Flows::MainMenuService.greeting(conversation:) if projekt.blank?

      Whatsapp::Flows::SendProjektCardService.call(conversation:, projekt: projekt)
    end

    # A projekt named by a tap on the participation list. Re-resolved rather
    # than trusted: the list may have been sent days ago, and a projekt that
    # has since closed has to reach the answer that says so.
    def offer_projekt_actions(projekt_id)
      projekt = ::Projekt.find_by(id: projekt_id)

      return Whatsapp::Flows::ProjektParticipationService.ask_projekt(conversation:) if
        projekt.blank?

      Whatsapp::Flows::ProjektParticipationService.offer_actions(conversation:, projekt: projekt)
    end

    def start_phase_flow(projekt_phase_id)
      projekt_phase = ::ProjektPhase.find_by(id: projekt_phase_id.to_i)

      return Whatsapp::Flows::RefuseParticipationService.call(conversation:, reason: :phase_missing) if
        !Whatsapp::EligiblePhasesQuery.eligible?(projekt_phase)

      Whatsapp::Flows::StartPhaseFlowService.call(conversation:, projekt_phase:)
    end
end
