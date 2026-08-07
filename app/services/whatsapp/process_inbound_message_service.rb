class Whatsapp::ProcessInboundMessageService < ApplicationService
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

    new_session = new_session?
    conversation.update!(last_inbound_at: latest_inbound_at)

    return if handle_stop_keywords
    return if account.opt_out_at.present?
    return Whatsapp::Flows::FirstContactService.call(conversation:) if first_contact?

    # The AI disclosure heads the session, so it is sent before anything below
    # can reply. A first contact is the exception: its own opening message
    # already carries the disclosure, and sending both would say it twice.
    Whatsapp::Flows::AiDisclosureService.call(conversation:) if new_session

    return if handle_recovery_action
    return if handle_flow_action
    return if handle_command
    return if @whatsapp_message.audio? && inbound_text.blank?

    entry = capture_entry_token

    return Whatsapp::Flows::SendLoginLinkService.call(conversation:) if account.user.blank?
    return handle_entry(entry) if entry.present?
    return if handle_stale_flow
    return if routed_by_assistant?

    dispatch_step
  end

  private

    # Everything above the assistant is protocol rather than dialogue — opting
    # out, a tapped pill, a scanned QR code — and stays deterministic. The
    # assistant sees only what is left, and hands back anything the flow owns.
    def routed_by_assistant?
      return false if !Ai::Settings.ai_available?
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

    # A session in WhatsApp's sense is the 24-hour service window, and it is
    # read before last_inbound_at is moved forward — afterwards every message
    # looks like it arrived inside the window it just opened.
    def new_session?
      last_seen = conversation.last_inbound_at

      last_seen.blank? || last_seen < ::Whatsapp::SERVICE_WINDOW.ago
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

    # The catalog uses one word for two things: "Stop" abandons the submission
    # in progress (C21), and "STOP" ends all messages for good (E34). The
    # difference is whether a submission is open, and it is decided here rather
    # than inside either service — getting it wrong means a citizen who wanted
    # to cancel a draft is silently unsubscribed instead.
    def handle_stop_keywords
      if Whatsapp::FlowActions::ABORT_KEYWORDS.include?(normalized_text) && conversation.drafting?
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
      idea_start category draft_publish draft_revise resume restart
      image_upload image_generate image_skip
      support notify_toggle notifications_done unlink_confirm unlink_cancel
    ].freeze

    def dispatch_flow_action(action, param)
      return Whatsapp::Flows::SendLoginLinkService.call(conversation:) if
        ACCOUNT_ACTIONS.include?(action) && account.user.blank?

      case action
      when :link_yes, :link_retry, :link_switch
        Whatsapp::Flows::SendLoginLinkService.call(conversation:)
      when :link_later
        Whatsapp::Flows::LinkDeclinedService.call(conversation:)
      when :discover
        Whatsapp::Flows::DiscoveryService.call(conversation:)
      when :discover_public
        Whatsapp::Flows::PublicDiscoveryService.call(conversation:)
      when :dismiss, :unlink_cancel
        conversation.reset_flow!
      when :unlink_confirm
        Whatsapp::Flows::ConfirmUnlinkService.call(conversation:)
      when :notify_toggle
        Whatsapp::Flows::ToggleNotificationService.call(conversation:, type: param)
      when :notifications_done
        finish_notification_settings
      when :idea_start
        start_phase_flow(param)
      when :category
        assign_category(param)
      when :draft_publish
        ask_image
      when :image_upload
        ask_image_upload
      when :image_generate
        generate_image_then_publish
      when :image_skip
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

      Whatsapp::Flows::UnlinkService.call(conversation:)

      true
    end

    def finish_notification_settings
      conversation.reset_flow!

      Whatsapp::Outbound.text(account:, body: I18n.t("whatsapp.bot.notifications.saved"))
    end

    def handle_entry(entry)
      return Whatsapp::Flows::RefuseParticipationService.call(conversation:, reason: :no_open_phase) if
        entry == :projekt_without_phase
      return Whatsapp::Flows::DiscoveryService.call(conversation:, projekt: entry_projekt) if
        entry == :projekt_choice

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

    # The draft can be gone by the time the question is answered — retention
    # purges, an admin deleting the phase — so "continue" falls back to asking
    # for the idea again rather than to a crash.
    def resume_flow
      return Whatsapp::Flows::PresentDraftService.first_draft(conversation:) if
        conversation.draft_resource.present?

      restart_flow
    end

    # Starting over inside a phase that is no longer taking submissions would
    # leave the citizen stuck on the resume question, answering it forever. When
    # there is nothing to restart into, the flow is dropped and the portal's
    # open projekts are offered instead.
    def restart_flow
      return Whatsapp::Flows::AskIdeaService.call(conversation:) if
        Whatsapp::EligiblePhasesQuery.eligible?(conversation.projekt_phase)

      conversation.reset_flow!

      Whatsapp::Flows::DiscoveryService.call(conversation:)
    end

    def start_phase_flow(projekt_phase_id)
      projekt_phase = ProjektPhase.find_by(id: projekt_phase_id.to_i)

      return Whatsapp::Flows::RefuseParticipationService.call(conversation:, reason: :phase_missing) if
        !Whatsapp::EligiblePhasesQuery.eligible?(projekt_phase)

      conversation.start_flow!(projekt_phase)

      Whatsapp::Flows::AskIdeaService.call(conversation:)
    end

    def assign_category(label_id)
      assigned = Whatsapp::DraftCategory.assign(
        conversation.draft_resource, conversation.projekt_phase, label_id
      )

      return Whatsapp::Flows::AskCategoryService.call(conversation:) if !assigned

      Whatsapp::Flows::PresentDraftService.first_draft(conversation:)
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
        Whatsapp::Flows::AskCategoryService.call(conversation:)
      when "awaiting_draft_decision"
        handle_draft_decision
      when "awaiting_image_choice"
        Whatsapp::Flows::AskImageService.call(conversation:)
      when "awaiting_image_upload"
        handle_image_upload
      when "awaiting_revision"
        handle_revision
      when "awaiting_comment"
        Whatsapp::Flows::CreateCommentService.call(conversation:, body: inbound_text)
      when "awaiting_notification_settings"
        Whatsapp::Flows::NotificationSettingsService.call(conversation:)
      when "awaiting_unlink_confirmation"
        Whatsapp::Flows::UnlinkService.call(conversation:)
      when "awaiting_resume_decision"
        Whatsapp::Flows::ResumeOrRestartService.call(conversation:)
      else
        Whatsapp::Flows::HelpService.call(conversation:)
      end
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
        Whatsapp::ResourceCreationValidationService.call(
          projekt_phase: conversation.projekt_phase,
          user: account.user
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

    def ask_revision
      conversation.update!(step: "awaiting_revision")

      Whatsapp::Outbound.text(account:, body: I18n.t("whatsapp.bot.proposal.ask_revision"))
    end

    def handle_revision
      correction = inbound_text.to_s.strip

      if correction.blank?
        return Whatsapp::Outbound.text(account:, body: I18n.t("whatsapp.bot.proposal.ask_revision"))
      end

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

      publish
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
    # the typing bubble covers the wait. A failure publishes anyway: the picture
    # was optional, and losing the proposal over it would be the worse outcome.
    def generate_image_then_publish
      Whatsapp::Outbound.text(account:, body: I18n.t("whatsapp.bot.proposal.image_generating"))
      Whatsapp::Outbound.typing(message_id: inbound_message_id)

      generated = Whatsapp::Flows::GenerateProposalImageService.call(conversation:)

      if !generated
        Whatsapp::Outbound.text(account:, body: I18n.t("whatsapp.bot.proposal.image_generate_failed"))
      end

      publish
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

      projekt_phase = ProjektPhase.find_by(id: projekt_phase_id)

      return if projekt_phase.blank?

      conversation.start_flow!(projekt_phase)

      :phase
    end

    def capture_projekt_token
      projekt_id = Whatsapp::QrToken.projekt_id_from(inbound_text)

      return if projekt_id.blank?

      projekt = Projekt.find_by(id: projekt_id)

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
      transcript = Whatsapp::TranscribeVoiceService.call(media_id: @raw_message.dig("audio", "id"))

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
