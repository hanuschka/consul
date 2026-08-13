class Whatsapp::Inbound::ProcessMessageService < ApplicationService
  # The one keyword list left. Every other typed message is read by a model,
  # but a typed opt-out word must end messages whether or not a provider is
  # reachable — an outage that keeps broadcasting to a number that asked us to
  # stop is the failure nothing may allow.
  OPT_OUT_KEYWORDS = ["stop", "stopp", "abmelden", "unsubscribe"].freeze

  # The model's own step map, aliased so every `when` below is a constant
  # reference: a typo is a NameError at load rather than a case branch that
  # never matches and reads as a silently ignored message.
  Step = Whatsapp::Conversation::Step

  def initialize(whatsapp_message:, raw_message: {})
    @whatsapp_message = whatsapp_message
    @raw_message = raw_message || {}
  end

  def call
    return if !::Whatsapp.enabled?

    conversation.update!(last_inbound_at: latest_inbound_at)

    consume_pending_question

    return if handle_stop_keywords
    return if handle_message_intent
    return if account.opt_out_at.present?
    return Whatsapp::Flows::OnboardingGreetingService.first_contact(conversation:) if first_contact?

    # The disclosure heads the citizen's first message, so it is sent before
    # anything below can reply. Once per number rather than once per 24-hour
    # window: a regular who reads it every day stops reading it at all. A first
    # contact is the exception, its own opening message already carries it.
    Whatsapp::Flows::OnboardingGreetingService.disclose(conversation:) if !account.ai_disclosed?

    return if handle_recovery_action
    return if handle_flow_action
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

    # Everything above the assistant is protocol rather than dialogue — the
    # typed STOP word, a tapped pill, a scanned QR code. The assistant sees
    # only what is left, and hands back anything the flow owns, together with
    # what it made of the message.
    #
    # An unlinked guest submitter skips it: half its tools act on a Consul
    # account, and a guest reaching them would only produce errors it cannot
    # explain. Their one model reading is the classifier's instead, so either
    # way a message is read exactly once.
    def routed_by_assistant?
      return false if !::Ai::Settings.ai_available?
      return false if account.user.blank?
      return false if tapped_reply_id.present?

      # A shared location is an answer to the step that asked for it, and it
      # carries no text at all — routing it would pay for a completion on an
      # empty message and could answer a pin with conversation.
      return false if inbound_location.present?

      result = Whatsapp::AiAssistant::RouterService.call(
        conversation: conversation,
        inbound_text: inbound_text,
        inbound_message_id: inbound_message_id
      )

      return false if !result.success?

      # A hand-off is not "routed": the flow still answers. What it made of the
      # message travels along, so the step below acts on the router's one
      # reading instead of asking a second model what was just decided.
      if result.outcome == :flow
        @flow_handoff = { verdict: result.decision, correction: result.correction }

        return false
      end

      true
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
    def handle_stop_keywords
      return false if !OPT_OUT_KEYWORDS.include?(normalized_text)

      if conversation.drafting?
        Whatsapp::Flows::CancelService.call(conversation:)
      else
        Whatsapp::Flows::MessageDeliveryService.disable(conversation:)
      end

      true
    end

    # The channel-level requests — leaving the channel, coming back to it,
    # abandoning what is in progress — decided by this message's one model
    # reading. A linked, subscribed citizen's one reading is the router's,
    # which carries stop_messages and abort_submission as tools, so the
    # classifier is never asked as well; it answers for everyone the router
    # does not serve.
    #
    # Never for a tapped pill, whose label the citizen did not write: those are
    # routed by their ids two gates below. A verdict the account's state rules
    # out is dropped rather than acted on — the model is told the state, but
    # what it answers is still only a reading.
    def handle_message_intent
      return false if tapped_reply_id.present?
      return false if !classifier_routes?

      case message_intent.verdict
      when :opt_out
        return false if account.opt_out_at.present?

        Whatsapp::Flows::MessageDeliveryService.disable(conversation:)
      when :opt_in
        return false if account.opt_out_at.blank?

        Whatsapp::Flows::MessageDeliveryService.enable(conversation:)
      when :abort
        return false if !interaction_open?

        Whatsapp::Flows::CancelService.call(conversation:)
      else
        return false
      end

      true
    end

    # Who this message's one model reading comes from. The router serves a
    # linked, subscribed citizen; the classifier serves everyone it will not —
    # guests and unlinked numbers, whose whole path is the deterministic flow,
    # and opted-out numbers, whose only open question is opting back in.
    def classifier_routes?
      account.user.blank? || account.opt_out_at.present?
    end

    # Asked once per message: the gate above reads the channel verdicts off it,
    # and the step handlers read the flow verdicts off the same result.
    def message_intent
      @message_intent ||= Whatsapp::AiAssistant::MessageIntentService.call(
        conversation: conversation,
        inbound_text: inbound_text,
        interaction_open: interaction_open?
      )
    end

    # The verdict this message already got from its one reading — the router's
    # hand-off for a linked citizen, the classifier for a guest — so no step
    # ever pays a second completion to re-derive it. Every degraded path — AI
    # switched off, a router turn that failed — reads as answer, which every
    # step treats as "just the message" and answers by re-asking.
    def flow_verdict
      return @flow_handoff[:verdict] if @flow_handoff.present?
      return message_intent.verdict if classifier_routes?

      :answer
    end

    def flow_correction
      return @flow_handoff[:correction] if @flow_handoff.present?
      return message_intent.correction if classifier_routes?

      nil
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

    # Handled ahead of the step dispatcher: a tapped recovery button must not be
    # read as idea text by whichever step happens to be active.
    #
    # Read off either shape of tap. A list carries no buttons beside it, so a
    # message offering rows has to put its way out among them, and a recovery id
    # cannot collide with a flow one: the two are built by different modules from
    # different prefixes.
    def handle_recovery_action
      action = Whatsapp::Outbound.recovery_action_from(tapped_reply_id)

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
    # Making a submission, which a guest phase does allow: these need an
    # account only when the phase they point at does.
    SUBMISSION_ACTIONS = %i[
      idea_start category sentiment draft_publish draft_revise resume restart
      image_upload image_generate image_skip location_share location_skip
      submit_final submit_anyway
    ].freeze

    # Supporting a proposal, reading your own submissions, changing
    # notification settings and unlinking all act on a Consul account, and a
    # guest has nothing to stand in for it with.
    #
    # my_contributions is here because the help list offers it to unlinked
    # numbers too: without the check it answers "you have not submitted
    # anything yet" to someone whose account is full of submissions, and never
    # mentions that linking is the missing part.
    ACCOUNT_ONLY_ACTIONS = %i[
      support support_instead support_prompt comment_prompt my_contributions
      notify_toggle notifications_done notifications_open
      unlink_confirm unlink_cancel unlink_start
    ].freeze

    # Derived from the two groups rather than listed a third time. The union is
    # what account_required? gates on, so an action named in only one of the
    # source lists is still gated; written out by hand, an account-only pill
    # left out of the union would skip the check entirely and reach the flow
    # with no user behind it.
    ACCOUNT_ACTIONS = (SUBMISSION_ACTIONS + ACCOUNT_ONLY_ACTIONS).freeze

    GUEST_ELIGIBLE_ACTIONS = SUBMISSION_ACTIONS

    def dispatch_flow_action(action, param)
      return Whatsapp::Flows::SendLoginLinkService.call(conversation:) if
        account_required?(action, param)

      case action
      when :link_yes, :link_retry
        Whatsapp::Flows::SendLoginLinkService.call(conversation:)
      when :link_switch
        Whatsapp::Flows::SendLoginLinkService.after_switch(conversation:)
      when :link_later
        Whatsapp::Flows::LinkOutcomeService.declined(conversation:)
      when :discover
        dispatch_discovery
      when :discover_public
        Whatsapp::Flows::DiscoveryService.unlinked(conversation:)
      when :submit_proposal
        Whatsapp::Flows::SubmitProposalService.call(conversation:)
      when :view_projekt
        send_projekt_card(param)
      when :my_contributions
        Whatsapp::Flows::ContributionsService.call(conversation:)
      when :main_menu
        Whatsapp::Flows::MainMenuService.greeting(conversation:)
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
        Whatsapp::Flows::NotificationSettingsService.toggle(conversation:, type: param)
      when :notifications_done
        finish_notification_settings
      when :idea_start
        start_phase_flow(param)
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
      when :support
        Whatsapp::Flows::SupportService.register(conversation:, proposal_id: param)
      when :support_instead
        Whatsapp::Flows::AskDuplicateChoiceService.support_instead(
          conversation:, proposal_id: param
        )
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

    # A help row that names something the assistant resolves rather than a flow
    # the bot owns. It asks the question and stops: the citizen's next message
    # is free text, and the assistant's own tools find the proposal in it.
    def send_menu_prompt(body_key)
      conversation.reset_flow!

      Whatsapp::Outbound.text(
        account:,
        body: Whatsapp.phrase(body_key)
      )
    end

    # The same branch whether the assistant called show_projekts or the citizen
    # tapped a pill that offers it. The pill is on the help list, which is what
    # an unlinked number is answered with, so the two cannot differ: the account
    # listing dead-ends for a guest and the public one does not.
    def dispatch_discovery
      return Whatsapp::Flows::DiscoveryService.unlinked(conversation:) if account.user.blank?

      Whatsapp::Flows::DiscoveryService.linked(conversation:)
    end

    def finish_notification_settings
      conversation.reset_flow!

      Whatsapp::Outbound.text(
        account:,
        body: Whatsapp.phrase("whatsapp.bot.notifications.saved")
      )
    end

    # Someone who scanned a QR code has just said what they want, and someone
    # mid-login is waiting on the link itself: both get it. A number that wrote
    # in with neither has not asked for a link — it declined one earlier, or its
    # link went cold — so the question is put again instead.
    def handle_unlinked(entry)
      return Whatsapp::Flows::OnboardingGreetingService.welcome_back(conversation:) if
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
      return Whatsapp::Flows::DiscoveryService.linked(conversation:, projekt: entry_projekt) if
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
      return false if conversation.awaiting_resume_decision?
      return false if !conversation.stale_flow?

      Whatsapp::Flows::ResumeOrRestartService.call(conversation:)

      true
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

      Whatsapp::Flows::StartPhaseFlowService.call(conversation:, projekt_phase:)
    end

    # A failed publish leaves the draft intact, so retrying means publishing
    # again; a failed draft leaves nothing behind but the text it was built from.
    #
    # A stored correction is preferred over the original idea: what failed was the
    # edit, and re-drafting from the idea instead would silently throw away the
    # change the citizen asked for. Cleared whenever a first draft is built, so it
    # cannot be re-applied to a draft it never belonged to.
    def retry_last_action
      return Whatsapp::Flows::PublishResultService.call(conversation:, inbound_message_id:) if
        conversation.awaiting_draft_decision? && conversation.draft_resource.present?

      last_correction = conversation.context["last_correction"]

      if last_correction.present?
        return Whatsapp::Flows::BuildDraftService.from_revision(
          conversation:, correction: last_correction, inbound_message_id:
        )
      end

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
      when Step::AWAITING_IDEA
        Whatsapp::Flows::AskIdeaService.handle_answer(
          conversation:, text: inbound_text, inbound_message_id:
        )
      when Step::AWAITING_CATEGORY
        Whatsapp::Flows::AskDraftChoiceService.category(conversation:)
      when Step::AWAITING_SENTIMENT
        Whatsapp::Flows::AskDraftChoiceService.sentiment(conversation:)
      when Step::AWAITING_DUPLICATE_DECISION
        Whatsapp::Flows::AskDuplicateChoiceService.handle_answer(conversation:)
      when Step::AWAITING_DRAFT_DECISION
        Whatsapp::Flows::PresentDraftService.handle_decision(
          conversation:, verdict: flow_verdict, correction: flow_correction,
          inbound_message_id:
        )
      when Step::AWAITING_IMAGE_CHOICE
        Whatsapp::Flows::ProposalImageService.handle_choice(
          conversation:, verdict: flow_verdict, inbound_message_id:
        )
      when Step::AWAITING_IMAGE_UPLOAD
        Whatsapp::Flows::ProposalImageService.handle_upload(
          conversation:, image_id: inbound_image_id, verdict: flow_verdict,
          inbound_message_id:
        )
      when Step::AWAITING_LOCATION
        Whatsapp::Flows::AskLocationService.handle_answer(
          conversation:, location: inbound_location, verdict: flow_verdict,
          inbound_message_id:
        )
      when Step::AWAITING_FINAL_CONFIRMATION
        Whatsapp::Flows::ConfirmSubmissionService.handle_decision(
          conversation:, verdict: flow_verdict, correction: flow_correction,
          inbound_message_id:
        )
      when Step::AWAITING_REVISION
        Whatsapp::Flows::AskRevisionService.handle_answer(
          conversation:, text: inbound_text, verdict: flow_verdict,
          inbound_message_id:
        )
      when Step::AWAITING_COMMENT
        Whatsapp::Flows::CommentService.create(conversation:, body: inbound_text)
      when Step::AWAITING_NOTIFICATION_SETTINGS
        Whatsapp::Flows::NotificationSettingsService.call(conversation:)
      when Step::AWAITING_UNLINK_CONFIRMATION
        Whatsapp::Flows::UnlinkService.ask(conversation:)
      when Step::AWAITING_RESUME_DECISION
        Whatsapp::Flows::ResumeOrRestartService.call(conversation:)
      else
        handle_idle_message
      end
    end

    # Nothing in progress and nothing the assistant could route. An unlinked
    # guest submitter reaches here too, and the menu answers them with the help
    # list rather than three buttons they mostly cannot use.
    def handle_idle_message
      Whatsapp::Flows::MainMenuService.greeting(conversation:)
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

    # The coordinates as WhatsApp's picker sent them, alongside an optional name
    # and address the flow has no use for — the pin is what a map renders.
    def inbound_location
      @raw_message["location"]
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
          conversation:,
          body: Whatsapp.phrase("whatsapp.bot.transcription_failed"),
          actions: [:cancel]
        )

        return nil
      end

      @whatsapp_message.update!(body: transcript)

      transcript
    end
end
