class Whatsapp::Inbound::ProcessMessageService < ApplicationService
  OPT_OUT_KEYWORDS = ["stop", "stopp", "abmelden", "unsubscribe"].freeze
  OPT_IN_KEYWORDS = ["start", "anmelden", "subscribe"].freeze
  PUBLISH_KEYWORDS = ["veröffentlichen", "veroeffentlichen", "publish", "ja", "senden"].freeze
  REVISE_KEYWORDS = ["ändern", "aendern", "korrigieren", "revise", "nein"].freeze
  SUBSCRIBE_COMMAND = /\A(subscribe|abonnieren|folgen)\s+(?<name>.+)\z/i
  UNSUBSCRIBE_COMMAND = /\A(unsubscribe|abbestellen|entfolgen)\s+(?<name>.+)\z/i

  def initialize(whatsapp_message:, raw_message: {})
    @whatsapp_message = whatsapp_message
    @raw_message = raw_message || {}
  end

  def call
    return if !::Whatsapp.enabled?

    conversation.update!(last_inbound_at: latest_inbound_at)

    consume_pending_question

    return if handle_stop_keywords
    return if account.opt_out_at.present?
    return Whatsapp::Flows::FirstContactService.call(conversation:) if first_contact?

    # The disclosure heads the citizen's first message, so it is sent before
    # anything below can reply. Once per number rather than once per 24-hour
    # window: a regular who reads it every day stops reading it at all. A first
    # contact is the exception, its own opening message already carries it.
    Whatsapp::Flows::AiDisclosureService.call(conversation:) if !account.ai_disclosed?

    return if handle_recovery_action
    return if handle_flow_action
    return if handle_command
    return if @whatsapp_message.audio? && inbound_text.blank?

    entry = capture_entry_token

    return handle_unlinked(entry) if account.user.blank? && !guest_participation?
    return handle_entry(entry) if entry.present?
    return if handle_stale_flow
    return if routed_by_assistant?

    dispatch_step
  end

  private

    # A phase that takes guest submissions on the web takes them here too, so an
    # unlinked number is not stopped at the door. It is still stopped later, by
    # the restrictions the phase carries — see ResourceCreationValidationService.
    def guest_participation?
      conversation.projekt_phase&.guest_participation?
    end

    def submission_author
      @submission_author ||= Whatsapp::Drafting::SubmissionAuthorService.call(conversation:)
    end

    # Everything above the assistant is protocol rather than dialogue — opting
    # out, a tapped pill, a scanned QR code — and stays deterministic. The
    # assistant sees only what is left, and hands back anything the flow owns.
    #
    # An unlinked guest submitter skips it: half its tools act on a Consul
    # account, and a guest reaching them would only produce errors it cannot
    # explain. Their whole path is the deterministic drafting flow.
    def routed_by_assistant?
      return false if !::Ai::Settings.ai_available?
      return false if account.user.blank?
      return false if tapped_reply_id.present?

      result = Whatsapp::AiAssistant::RouterService.call(
        conversation: conversation,
        inbound_text: inbound_text,
        inbound_message_id: inbound_message_id
      )

      return false if !result.success?

      result.outcome != :flow
    end

    # A tapped row or button already says exactly what it means, and the text
    # WhatsApp sends alongside it is only that row's own label. The steps below
    # read the id; sending the label to the assistant instead would pay for a
    # completion to re-derive it, and risk a tapped "Yes, submit it" being
    # answered as conversation rather than publishing the draft.
    def tapped_reply_id
      list_reply_id.presence || button_reply_id.presence
    end

    def first_contact?
      return true if @whatsapp_message.welcome? && !account.greeted?

      account.user_id.blank? && !account.greeted?
    end

    # Only ever forwards: a retried or out-of-order delivery must not rewind the
    # conversation's clock.
    def latest_inbound_at
      [@whatsapp_message.sent_at || Time.current, conversation.last_inbound_at].compact.max
    end

    def account
      @account ||= @whatsapp_message.whatsapp_account
    end

    def conversation
      @conversation ||= account.conversation
    end

    # The catalog uses one word for two things: "Stop" abandons what is in
    # progress (C21), and "STOP" ends all messages for good (E34). Decided here
    # rather than inside either service — getting it wrong means a citizen who
    # wanted to cancel is silently unsubscribed instead.
    def abort_interaction?
      return false if !Whatsapp::FlowActions::ABORT_KEYWORDS.include?(normalized_text)

      # "stop" and "stopp" are also the opt-out words, and they are what someone
      # types to leave the channel, so they abort only a submission actually in
      # progress. Reading them any wider would answer a link invitation or a
      # settings list with "cancelled" and never write opt_out_at, leaving us
      # broadcasting to a number that asked us to stop.
      return conversation.drafting? if OPT_OUT_KEYWORDS.include?(normalized_text)

      interaction_open?
    end

    # A word that cannot mean "leave the channel" dismisses whatever the bot last
    # asked. Any step other than idle is that, and so is an idle conversation
    # holding a question: the assistant's own button replies leave the step at
    # idle, so the step alone cannot tell the two apart.
    def interaction_open?
      return true if !conversation.idle?

      pending_question?
    end

    def pending_question?
      @pending_question
    end

    # Read and cleared in the same breath. The flag answers "was the bot's last
    # message a question", which is true only for the message that follows it —
    # consumed before any gate below can return early, so no branch can leave it
    # set and turn an "abbrechen" days later into a cancellation.
    def consume_pending_question
      @pending_question = conversation.context["pending_question"].present?

      return if !@pending_question

      conversation.merge_context!(pending_question: nil)
    end

    def handle_stop_keywords
      if abort_interaction?
        Whatsapp::Flows::CancelService.call(conversation:)

        return true
      end

      if OPT_OUT_KEYWORDS.include?(normalized_text)
        Whatsapp::Flows::MessageDeliveryService.disable(conversation:)

        return true
      end

      if OPT_IN_KEYWORDS.include?(normalized_text)
        Whatsapp::Flows::MessageDeliveryService.enable(conversation:)

        return true
      end

      false
    end

    # Handled ahead of the step dispatcher: a tapped recovery button must not be
    # read as idea text by whichever step happens to be active.
    def handle_recovery_action
      action = Whatsapp::Outbound.recovery_action_from(button_reply_id)

      return false if action.blank?

      case action
      when :help then Whatsapp::Flows::HelpService.call(conversation:)
      when :cancel then Whatsapp::Flows::CancelService.call(conversation:)
      when :retry then retry_last_action
      end

      true
    end

    def handle_flow_action
      return false if flow_action.blank?

      dispatch_flow_action(flow_action[:action], flow_action[:param])

      true
    end

    def flow_action
      return @flow_action if defined?(@flow_action)

      @flow_action = Whatsapp::FlowActions.parse(tapped_reply_id)
    end

    # One place every pill in the catalog lands. Actions that need an account
    # are refused here rather than in each service, so reading the portal never
    # dead-ends into "connect an account" and participating never silently
    # skips the check.
    ACCOUNT_ACTIONS = %i[
      idea_start category sentiment draft_publish draft_revise resume restart
      image_upload image_generate image_skip submit_final
      support support_prompt comment_prompt
      notify_toggle notifications_done notifications_open
      unlink_confirm unlink_cancel unlink_start
    ].freeze

    # Supporting a proposal, changing notification settings and unlinking all
    # act on a Consul account, and a guest has nothing to stand in for it with.
    # Everything else in ACCOUNT_ACTIONS is part of making a submission, which a
    # guest phase does allow — derived rather than listed again so a new
    # drafting pill cannot be added to one list and forgotten in the other.
    ACCOUNT_ONLY_ACTIONS = %i[
      support support_prompt comment_prompt
      notify_toggle notifications_done notifications_open
      unlink_confirm unlink_cancel unlink_start
    ].freeze

    GUEST_ELIGIBLE_ACTIONS = (ACCOUNT_ACTIONS - ACCOUNT_ONLY_ACTIONS).freeze

    def dispatch_flow_action(action, param)
      return Whatsapp::Flows::SendLoginLinkService.call(conversation:) if
        account_required?(action, param)

      case action
      when :link_yes, :link_retry
        Whatsapp::Flows::SendLoginLinkService.call(conversation:)
      when :link_switch
        Whatsapp::Flows::SendLoginLinkService.after_switch(conversation:)
      when :link_later
        Whatsapp::Flows::LinkDeclinedService.call(conversation:)
      when :discover
        Whatsapp::Flows::DiscoveryService.call(conversation:)
      when :discover_public
        Whatsapp::Flows::PublicDiscoveryService.call(conversation:)
      when :submit_proposal
        Whatsapp::Flows::SubmitProposalService.call(conversation:)
      when :view_projekt
        send_projekt_card(param)
      when :my_contributions
        Whatsapp::Flows::ContributionsService.call(conversation:)
      when :main_menu
        send_main_menu
      when :support_prompt
        send_menu_prompt("whatsapp.bot.help_menu.prompts.support")
      when :comment_prompt
        send_menu_prompt("whatsapp.bot.help_menu.prompts.comment")
      when :notifications_open
        Whatsapp::Flows::NotificationSettingsService.call(conversation:)
      when :unlink_start
        Whatsapp::Flows::UnlinkService.ask(conversation:)
      when :dismiss, :unlink_cancel
        conversation.reset_flow!
      when :unlink_confirm
        Whatsapp::Flows::UnlinkService.confirm(conversation:)
      when :notify_toggle
        Whatsapp::Flows::ToggleNotificationService.call(conversation:, type: param)
      when :notifications_done
        finish_notification_settings
      when :idea_start
        start_phase_flow(param)
      when :category
        assign_category(param)
      when :sentiment
        assign_sentiment(param)
      when :draft_publish
        ask_image
      when :image_upload
        ask_image_upload
      when :image_generate
        generate_image_then_confirm
      when :image_skip, :submit_final
        publish
      when :draft_revise
        ask_revision
      when :resume
        resume_flow
      when :restart
        restart_flow
      when :support
        Whatsapp::Flows::RegisterSupportService.call(conversation:, proposal_id: param)
      end
    end

    def account_required?(action, param)
      return false if !ACCOUNT_ACTIONS.include?(action)
      return false if account.user.present?

      !guest_action?(action, param)
    end

    # Read from the phase the action points at rather than the conversation's:
    # idea_start carries its own phase id, and it is the tap that opens the flow
    # in the first place.
    def guest_action?(action, param)
      return false if !GUEST_ELIGIBLE_ACTIONS.include?(action)

      target_phase_for(action, param)&.guest_participation?
    end

    def target_phase_for(action, param)
      return conversation.projekt_phase if action != :idea_start

      ::ProjektPhase.find_by(id: param)
    end

    # A word a citizen types instead of tapping. Matched only as the whole
    # message, so a sentence that happens to contain "help" still reaches the
    # assistant.
    def handle_command
      return send_help if Whatsapp::FlowActions::HELP_KEYWORDS.include?(normalized_text)
      return send_discovery if Whatsapp::FlowActions::DISCOVERY_KEYWORDS.include?(normalized_text)
      return send_notification_settings if
        Whatsapp::FlowActions::NOTIFICATION_KEYWORDS.include?(normalized_text)
      return start_unlink if Whatsapp::FlowActions::UNLINK_KEYWORDS.include?(normalized_text)

      handle_subscription_command
    end

    # The catalog manages subscriptions by typed command, with no menu to
    # navigate. Matched deterministically first so the common, exactly-worded
    # case costs no completion; anything looser falls through to the assistant,
    # which resolves the name with its own tool.
    def handle_subscription_command
      subscribe = SUBSCRIBE_COMMAND.match(inbound_text.to_s.strip)
      unsubscribe = UNSUBSCRIBE_COMMAND.match(inbound_text.to_s.strip)

      return false if subscribe.blank? && unsubscribe.blank?
      return false if account.user.blank?

      run_subscription_command(subscribe, unsubscribe)

      true
    end

    def run_subscription_command(subscribe, unsubscribe)
      match = subscribe || unsubscribe
      projekt = Whatsapp::ProjektByNameQuery.call(term: match[:name])

      return Whatsapp::Flows::SubscriptionCommandService.subscribe(conversation:, projekt:) if
        subscribe.present?

      Whatsapp::Flows::SubscriptionCommandService.unsubscribe(conversation:, projekt:)
    end

    def send_help
      Whatsapp::Flows::HelpService.call(conversation:)

      true
    end

    # An unlinked guest has no contributions and no notification settings, so
    # the three-button menu would offer them two dead ends. The help list is
    # already the answer they get when nothing is in progress.
    def send_main_menu
      return Whatsapp::Flows::HelpService.call(conversation:) if account.user.blank?

      Whatsapp::Flows::MainMenuService.greeting(conversation:)
    end

    # A help row that names something the assistant resolves rather than a flow
    # the bot owns. It asks the question and stops: the citizen's next message
    # is free text, and the assistant's own tools find the proposal in it.
    def send_menu_prompt(body_key)
      conversation.reset_flow!

      Whatsapp::Outbound.text(account:, body: I18n.t(body_key))
    end

    # Answered deterministically rather than left to the assistant so the
    # command menu's own word still works on a portal with AI switched off.
    def send_discovery
      return Whatsapp::Flows::PublicDiscoveryService.call(conversation:).then { true } if
        account.user.blank?

      Whatsapp::Flows::DiscoveryService.call(conversation:)

      true
    end

    def send_notification_settings
      return Whatsapp::Flows::SendLoginLinkService.call(conversation:).then { true } if
        account.user.blank?

      Whatsapp::Flows::NotificationSettingsService.call(conversation:)

      true
    end

    def start_unlink
      return false if account.user.blank?

      Whatsapp::Flows::UnlinkService.ask(conversation:)

      true
    end

    def finish_notification_settings
      conversation.reset_flow!

      Whatsapp::Outbound.text(account:, body: I18n.t("whatsapp.bot.notifications.saved"))
    end

    # Someone who scanned a QR code has just said what they want, and someone
    # mid-login is waiting on the link itself: both get it. A number that wrote
    # in with neither has not asked for a link — it declined one earlier, or its
    # link went cold — so the question is put again instead.
    def handle_unlinked(entry)
      return Whatsapp::Flows::WelcomeBackService.call(conversation:) if
        entry.blank? && !account.awaiting_link?

      Whatsapp::Flows::SendLoginLinkService.call(conversation:)
    end

    # A phase QR code names the phase, so the citizen has already chosen and is
    # asked for their idea. A projekt QR code with one open phase has chosen only
    # the projekt: they get its card first, because the phase is this bot's
    # inference and not their decision.
    def handle_entry(entry)
      return Whatsapp::Flows::RefuseParticipationService.call(conversation:, reason: :no_open_phase) if
        entry == :projekt_without_phase
      return Whatsapp::Flows::DiscoveryService.call(conversation:, projekt: entry_projekt) if
        entry == :projekt_choice

      return Whatsapp::Flows::ProposalPromptService.call(
        conversation:, projekt_phase: conversation.projekt_phase
      ) if entry == :projekt

      Whatsapp::Flows::AskIdeaService.call(conversation:)
    end

    # A draft older than the catalog's 3600 minutes is not resumed silently.
    # Only asked once — the question itself moves the step, so the next message
    # is an answer to it rather than a second asking.
    def handle_stale_flow
      return false if !conversation.drafting?
      return false if conversation.step == "awaiting_resume_decision"
      return false if !conversation.stale_flow?

      Whatsapp::Flows::ResumeOrRestartService.call(conversation:)

      true
    end

    # The recap goes first either way: hours or days passed since the draft was
    # started, and the step being resumed says nothing about which projekt it
    # belongs to. The draft can also be gone by then — retention purges, an admin
    # deleting the phase — in which case the idea is asked for again inside the
    # same phase rather than sending the citizen back to the entry question.
    #
    # A phase deleted outright leaves nothing to resume into and nothing for
    # AskIdeaService to move the step with, so it restarts instead — otherwise
    # every later message would re-ask the resume question it cannot answer.
    def resume_flow
      return restart_flow if conversation.projekt_phase.blank?

      # The clock the staleness question is asked off is only stamped by
      # start_flow!, and resuming moves the step without going through it. Left
      # alone, the resumed step would be found stale again by the citizen's very
      # next message and the same question asked forever.
      conversation.merge_context!(flow_started_at: Time.current.iso8601)

      Whatsapp::Flows::ResumeRecapService.call(conversation:)

      return Whatsapp::Flows::PresentDraftService.first_draft(conversation:) if
        conversation.draft_resource.present?

      Whatsapp::Flows::AskIdeaService.call(conversation:)
    end

    # Starting over drops the draft and asks the entry question again rather than
    # the idea question: by the time the resume prompt is answered the citizen may
    # not remember which projekt the conversation was in, and "tell me your idea"
    # names none. SubmitProposalService re-derives what is open, so a phase that
    # closed in the meantime cannot be restarted into.
    def restart_flow
      conversation.reset_flow!

      Whatsapp::Flows::SubmitProposalService.call(conversation:)
    end

    # The card on its own, for a citizen who wanted to look before deciding. No
    # flow is started and nothing is remembered: the submission button on the
    # card they were just sent is still there to come back to.
    def send_projekt_card(projekt_id)
      projekt = ::Projekt.find_by(id: projekt_id)

      return Whatsapp::Flows::HelpService.call(conversation:) if projekt.blank?

      Whatsapp::Flows::SendProjektCardService.call(conversation:, projekt: projekt)
    end

    def start_phase_flow(projekt_phase_id)
      projekt_phase = ::ProjektPhase.find_by(id: projekt_phase_id.to_i)

      return Whatsapp::Flows::RefuseParticipationService.call(conversation:, reason: :phase_missing) if
        !Whatsapp::EligiblePhasesQuery.eligible?(projekt_phase)

      conversation.start_flow!(projekt_phase)

      Whatsapp::Flows::AskIdeaService.call(conversation:)
    end

    # Before the record exists the answer goes into the stashed draft data,
    # because the validation it satisfies runs at creation and the record cannot
    # be written until it is satisfied. Afterwards it goes onto the record,
    # where the citizen is correcting a choice rather than supplying a missing
    # one. Either way CompleteDraftService decides what is still outstanding.
    def assign_category(label_id)
      return stash_draft_choice(:projekt_label_ids, [label_id.to_i]) if pre_creation_draft?

      assigned = Whatsapp::DraftCategory.assign(
        conversation.draft_resource, conversation.projekt_phase, label_id
      )

      return Whatsapp::Flows::AskDraftChoiceService.category(conversation:) if !assigned

      complete_draft
    end

    def assign_sentiment(sentiment_id)
      return stash_draft_choice(:sentiment_id, sentiment_id.to_i) if pre_creation_draft?

      assigned = Whatsapp::DraftSentiment.assign(
        conversation.draft_resource, conversation.projekt_phase, sentiment_id
      )

      return Whatsapp::Flows::AskDraftChoiceService.sentiment(conversation:) if !assigned

      complete_draft
    end

    def pre_creation_draft?
      conversation.draft_resource.blank? && conversation.context["draft_data"].present?
    end

    # Written back through the same key the generation call filled, so
    # DraftCategory and DraftSentiment re-validate the answer against the phase
    # exactly as it validated the model's.
    def stash_draft_choice(key, value)
      draft_data = conversation.context["draft_data"].to_h.merge(key.to_s => value)
      conversation.merge_context!(draft_data: draft_data)

      complete_draft
    end

    def complete_draft
      Whatsapp::Flows::CompleteDraftService.for_first_draft(conversation:, inbound_message_id:)
    end

    # A failed publish leaves the draft intact, so retrying means publishing
    # again; a failed draft leaves nothing behind but the text it was built from.
    def retry_last_action
      return publish if conversation.step == "awaiting_draft_decision" &&
                        conversation.draft_resource.present?

      last_idea_text = conversation.context["last_idea_text"]

      if last_idea_text.present?
        return Whatsapp::Flows::BuildDraftService.from_idea(
          conversation:, idea_text: last_idea_text, inbound_message_id:
        )
      end

      Whatsapp::Flows::HelpService.call(conversation:)
    end

    def dispatch_step
      case conversation.step
      when "awaiting_idea"
        handle_idea
      when "awaiting_category"
        Whatsapp::Flows::AskDraftChoiceService.category(conversation:)
      when "awaiting_sentiment"
        Whatsapp::Flows::AskDraftChoiceService.sentiment(conversation:)
      when "awaiting_draft_decision"
        handle_draft_decision
      when "awaiting_image_choice"
        Whatsapp::Flows::AskImageService.call(conversation:)
      when "awaiting_image_upload"
        handle_image_upload
      when "awaiting_final_confirmation"
        handle_final_confirmation
      when "awaiting_revision"
        handle_revision
      when "awaiting_comment"
        Whatsapp::Flows::CreateCommentService.call(conversation:, body: inbound_text)
      when "awaiting_notification_settings"
        Whatsapp::Flows::NotificationSettingsService.call(conversation:)
      when "awaiting_unlink_confirmation"
        Whatsapp::Flows::UnlinkService.ask(conversation:)
      when "awaiting_resume_decision"
        Whatsapp::Flows::ResumeOrRestartService.call(conversation:)
      else
        handle_idle_message
      end
    end

    # Nothing in progress and nothing the assistant could route. Only an
    # unlinked guest submitter reaches here without an account, and the greeting
    # offers contributions and notification settings they have none of — so the
    # help list stays their answer.
    def handle_idle_message
      return Whatsapp::Flows::HelpService.call(conversation:) if account.user.blank?

      Whatsapp::Flows::MainMenuService.greeting(conversation:)
    end

    def handle_idea
      idea_text = inbound_text.to_s.strip

      if idea_text.blank?
        return Whatsapp::Outbound.recovery(
          conversation:, body: I18n.t("whatsapp.bot.idea_missing"), actions: [:cancel]
        )
      end

      return if refuse_if_not_permitted

      Whatsapp::Flows::BuildDraftService.from_idea(
        conversation:, idea_text: idea_text, inbound_message_id:
      )
    end

    # Checked again per action rather than once at flow entry: the same three
    # steps can be minutes or days apart, and a phase that expires in between
    # must stop an idea before it costs a draft and stop a draft before it
    # becomes a proposal.
    def refuse_if_not_permitted
      permission_problem =
        Whatsapp::Drafting::ResourceCreationValidationService.call(
          projekt_phase: conversation.projekt_phase,
          user: submission_author
        )

      return false if permission_problem.blank?

      Whatsapp::Flows::RefuseParticipationService.call(conversation:, reason: permission_problem)

      true
    end

    def handle_draft_decision
      return publish if PUBLISH_KEYWORDS.include?(normalized_text)
      return ask_revision if REVISE_KEYWORDS.include?(normalized_text)

      Whatsapp::Flows::PresentDraftService.first_draft(conversation:)
    end

    # The same "ja" that publishes from the draft card publishes from the
    # preview, because the two look alike and a citizen who typed it once will
    # type it again. Anything else re-sends the preview rather than guessing.
    def handle_final_confirmation
      return publish if PUBLISH_KEYWORDS.include?(normalized_text)

      Whatsapp::Flows::ConfirmSubmissionService.call(conversation:)
    end

    def ask_revision
      conversation.update!(step: "awaiting_revision")

      send_revision_question
    end

    def send_revision_question
      Whatsapp::Outbound.text(
        account:,
        body: Whatsapp::AiAssistant::PhrasingService.call(
          key: "whatsapp.bot.proposal.ask_revision"
        )
      )
    end

    def handle_revision
      correction = inbound_text.to_s.strip

      return send_revision_question if correction.blank?

      conversation.update!(revisions_count: conversation.revisions_count + 1)

      Whatsapp::Flows::BuildDraftService.from_revision(
        conversation:, idea_text: revised_idea_text(correction), inbound_message_id:
      )
    end

    def revised_idea_text(correction)
      [conversation.draft_resource&.ai_idea_text, correction].compact.join("\n\n")
    end

    # The picture is offered between confirming the draft and publishing it, so
    # the permission re-check moves here: refusing after a citizen has already
    # chosen and uploaded an image would waste the one thing they had to do
    # work for.
    def ask_image
      return if refuse_if_not_permitted

      Whatsapp::Flows::AskImageService.call(conversation:)
    end

    def ask_image_upload
      conversation.update!(step: "awaiting_image_upload")

      send_upload_prompt("whatsapp.bot.proposal.image_upload_prompt")
    end

    # A photo sent while the bot is waiting for one. Anything else at this step
    # is answered by asking again rather than by silently publishing without the
    # picture the citizen said they wanted to send.
    def handle_image_upload
      return send_upload_prompt("whatsapp.bot.proposal.image_upload_prompt") if
        inbound_image_id.blank?

      attached = Whatsapp::Flows::AttachUploadedImageService.call(
        conversation:, media_id: inbound_image_id
      )

      return send_upload_prompt("whatsapp.bot.proposal.image_failed") if !attached

      Whatsapp::Outbound.text(account:, body: I18n.t("whatsapp.bot.proposal.image_received"))

      confirm_submission
    end

    # Every prompt at this step carries the same way out, so the citizen is
    # never stuck waiting to be asked for a photo they cannot send.
    def send_upload_prompt(body_key)
      Whatsapp::Outbound.buttons(
        account: account,
        body: I18n.t(body_key),
        buttons: [
          Whatsapp::FlowActions.button(
            action: :image_skip, label_key: "whatsapp.bot.buttons.image_skip"
          )
        ]
      )
    end

    # Generation is a slow external call, so the citizen is told it started and
    # the typing bubble covers the wait. A failure goes on anyway: the picture
    # was optional, and losing the proposal over it would be the worse outcome.
    def generate_image_then_confirm
      Whatsapp::Outbound.text(account:, body: I18n.t("whatsapp.bot.proposal.image_generating"))
      Whatsapp::Outbound.typing(message_id: inbound_message_id)

      generated = Whatsapp::Flows::GenerateProposalImageService.call(conversation:)

      if !generated
        Whatsapp::Outbound.text(account:, body: I18n.t("whatsapp.bot.proposal.image_generate_failed"))
      end

      confirm_submission
    end

    # Only the two paths that produced a picture stop here. "Ohne Bild
    # einreichen" says what it does and publishes on the tap: a preview of a
    # draft the citizen approved two messages ago, with nothing new on it,
    # would be a confirmation of nothing.
    def confirm_submission
      return if refuse_if_not_permitted

      Whatsapp::Flows::ConfirmSubmissionService.call(conversation:)
    end

    def publish
      return if refuse_if_not_permitted

      Whatsapp::Flows::PublishResultService.call(conversation:, inbound_message_id:)
    end

    # Stores what a QR deep link points at without sending anything, so the
    # caller decides the reply (the login link first for unlinked numbers).
    # Returns nil, :phase, :projekt, :projekt_choice or :projekt_without_phase.
    def capture_entry_token
      capture_phase_token || capture_projekt_token
    end

    def capture_phase_token
      projekt_phase_id = Whatsapp::QrToken.projekt_phase_id_from(inbound_text)

      return if projekt_phase_id.blank?

      projekt_phase = ::ProjektPhase.find_by(id: projekt_phase_id)

      return if projekt_phase.blank?

      conversation.start_flow!(projekt_phase)

      :phase
    end

    def capture_projekt_token
      projekt_id = Whatsapp::QrToken.projekt_id_from(inbound_text)

      return if projekt_id.blank?

      projekt = ::Projekt.find_by(id: projekt_id)

      return if projekt.blank?

      store_projekt_entry(projekt)
    end

    def store_projekt_entry(projekt)
      eligible_phases = Whatsapp::EligiblePhasesQuery.call(projekt: projekt)

      return :projekt_without_phase if eligible_phases.empty?

      if eligible_phases.one?
        conversation.start_flow!(eligible_phases.first)

        return :projekt
      end

      conversation.reset_flow!
      @entry_projekt = projekt

      :projekt_choice
    end

    def entry_projekt
      @entry_projekt
    end

    # The wamid of the message being answered. WhatsApp ties a typing indicator
    # to one inbound message, so the slow paths need it to show the bubble.
    def inbound_message_id
      @whatsapp_message.wa_message_id
    end

    def button_reply_id
      @raw_message.dig("interactive", "button_reply", "id") ||
        @raw_message.dig("button", "payload")
    end

    def inbound_image_id
      @raw_message.dig("image", "id")
    end

    def list_reply_id
      @raw_message.dig("interactive", "list_reply", "id")
    end

    def normalized_text
      @normalized_text ||= inbound_text.to_s.strip.downcase
    end

    def inbound_text
      return @inbound_text if defined?(@inbound_text)

      @inbound_text =
        if @whatsapp_message.audio?
          transcribed_text
        else
          @whatsapp_message.body
        end
    end

    def transcribed_text
      transcript = Whatsapp::Inbound::TranscribeVoiceService.call(media_id: @raw_message.dig("audio", "id"))

      if transcript.blank?
        Whatsapp::Outbound.recovery(
          conversation:, body: I18n.t("whatsapp.bot.transcription_failed"), actions: [:cancel]
        )

        return nil
      end

      @whatsapp_message.update!(body: transcript)

      transcript
    end
end
