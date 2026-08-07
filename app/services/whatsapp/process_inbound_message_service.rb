class Whatsapp::ProcessInboundMessageService < ApplicationService
  OPT_OUT_KEYWORDS = ["stop", "stopp", "abmelden", "unsubscribe"].freeze
  OPT_IN_KEYWORDS = ["start", "anmelden", "subscribe"].freeze
  PUBLISH_KEYWORDS = ["veröffentlichen", "veroeffentlichen", "publish", "ja", "senden"].freeze
  REVISE_KEYWORDS = ["ändern", "aendern", "korrigieren", "revise", "nein"].freeze
  DRAFT_INTERVAL = 15.seconds

  def initialize(whatsapp_message:, raw_message: {})
    @whatsapp_message = whatsapp_message
    @raw_message = raw_message || {}
  end

  def call
    return if !::Whatsapp.enabled?

    conversation.update!(last_inbound_at: latest_inbound_at)

    return if handle_opt_keywords
    return if account.opt_out_at.present?

    # Opening the chat for the first time carries no text to interpret, so the
    # only sensible answer is the menu of what is open.
    return send_entry_menu if @whatsapp_message.welcome?
    return if handle_recovery_action
    return if handle_notification_action
    return if handle_command
    return if handle_public_menu_action

    return if @whatsapp_message.audio? && inbound_text.blank?

    entry = capture_entry_token

    return Whatsapp::Steps::SendLinkInvitationService.call(conversation:) if account.user.blank?
    return Whatsapp::Steps::RefuseParticipationService.call(conversation:, reason: :no_open_phase) if
      entry == :projekt_without_phase
    return Whatsapp::NextStepService.call(conversation:) if entry.present?
    return if handle_account_menu_action
    return if routed_by_assistant?

    dispatch_step
  end

  private

    # Everything above this point is protocol rather than dialogue — opting out,
    # a tapped recovery button, a scanned QR code — and stays deterministic. The
    # assistant sees only what is left, and hands back anything the flow owns.
    def routed_by_assistant?
      return false if !Ai::Settings.ai_available?
      return false if tapped_reply_id.present?

      result = Whatsapp::AiAssistant::RouterService.call(
        conversation: conversation,
        inbound_text: inbound_text
      )

      return false if !result.success?

      result.outcome != :flow
    end

    # A tapped row or button already says exactly what it means, and the text
    # WhatsApp sends alongside it is only that row's own label. The steps below
    # read the id; sending the label to the assistant instead would pay for a
    # completion to re-derive it, and risk a tapped "Veröffentlichen" being
    # answered as conversation rather than publishing the draft.
    def tapped_reply_id
      list_reply_id.presence || button_reply_id.presence
    end

    # Only ever forwards, for the same reason the account's copy is: a retried
    # or out-of-order delivery must not rewind the conversation's clock.
    def latest_inbound_at
      [@whatsapp_message.sent_at || Time.current, conversation.last_inbound_at].compact.max
    end

    def account
      @account ||= @whatsapp_message.whatsapp_account
    end

    def conversation
      @conversation ||= account.conversation
    end

    # Handled ahead of the step dispatcher: a tapped recovery button must not be
    # read as idea text by whichever step happens to be active.
    def handle_recovery_action
      action = Whatsapp::Outbound.recovery_action_from(button_reply_id)

      return false if action.blank?

      case action
      when :menu then send_entry_menu
      when :cancel then cancel_flow
      when :retry then retry_last_action
      end

      true
    end

    # The one caller shape that must ignore the open flow: an empty chat and a
    # tapped menu button both mean "start from what the portal has", so the flow
    # is dropped before asking what comes next.
    def send_entry_menu
      conversation.reset_flow!

      Whatsapp::Steps::MainMenuService.call(conversation:)
    end

    # A word the number's own command menu advertises answers the same way every
    # time, whatever the conversation was doing. Matched only as the whole
    # message, so a sentence that happens to contain "menu" still reaches the
    # assistant.
    def handle_command
      action = Whatsapp::MenuActions.command_action_from(normalized_text)

      return false if action.blank?
      return send_entry_menu.then { true } if action == :menu

      Whatsapp::MenuActionService.call(
        conversation: conversation, scope: :portal, action: action
      )
    end

    # Turning messages off must work from any state and must never depend on a
    # model reading the request correctly, so it sits with the recovery buttons
    # rather than behind the assistant.
    def handle_notification_action
      action = Whatsapp::NotificationActions.action_from(button_reply_id)

      return false if action.blank?

      set_message_delivery(action)

      true
    end

    def set_message_delivery(action)
      return Whatsapp::Steps::SetMessageDeliveryService.enable(conversation:) if action == :messages_on

      Whatsapp::Steps::SetMessageDeliveryService.disable(conversation:)
    end

    # Tapped rows and buttons carry an unambiguous action, so they are answered
    # here for the same reason recovery buttons are: sending one through the
    # assistant would pay for a completion to re-derive what the id already
    # says, and risk it being read as something else.
    #
    # Split in two by what the action needs. Reading the portal needs no
    # account, so those are answered before the linking check rather than after
    # it — asking someone to connect an account to read a public result would be
    # a dead end they did not ask for.
    def handle_public_menu_action
      return false if menu_action.blank?
      return false if Whatsapp::MenuActions.needs_account?(menu_action[:action])

      dispatch_menu_action
    end

    def handle_account_menu_action
      return false if menu_action.blank?

      dispatch_menu_action
    end

    def dispatch_menu_action
      Whatsapp::MenuActionService.call(
        conversation: conversation,
        scope: menu_action[:scope],
        record_id: menu_action[:record_id],
        action: menu_action[:action]
      )
    end

    def menu_action
      return @menu_action if defined?(@menu_action)

      @menu_action = Whatsapp::MenuActions.parse(tapped_reply_id)
    end

    def cancel_flow
      conversation.reset_flow!

      Whatsapp::Outbound.text(account:, body: I18n.t("whatsapp.bot.cancelled"))
      Whatsapp::Steps::MainMenuService.call(conversation:)
    end

    # A failed publish leaves the draft intact, so retrying means publishing
    # again; a failed draft leaves nothing behind but the text it was built from.
    def retry_last_action
      return publish if conversation.step == "awaiting_draft_decision" && conversation.draft_resource.present?

      last_idea_text = conversation.context["last_idea_text"]

      return generate_draft(last_idea_text) if last_idea_text.present?

      Whatsapp::NextStepService.call(conversation:)
    end

    def send_recovery(body, actions)
      Whatsapp::Outbound.recovery(conversation:, body:, actions:)
    end

    def dispatch_step
      case conversation.step
      when "awaiting_phase_choice"
        handle_phase_choice
      when "awaiting_idea"
        handle_idea
      when "awaiting_draft_decision"
        handle_draft_decision
      when "awaiting_revision"
        handle_revision
      else
        Whatsapp::NextStepService.call(conversation:)
      end
    end

    def handle_phase_choice
      chosen_id = Whatsapp::Steps::AskPhaseChoiceService.projekt_phase_id_from_row(list_reply_id)
      offered_ids = Array(conversation.context["phase_choice_ids"]).map(&:to_i)
      projekt_phase = ProjektPhase.find_by(id: chosen_id) if offered_ids.include?(chosen_id)

      return Whatsapp::NextStepService.call(conversation:) if projekt_phase.blank?

      conversation.start_flow!(projekt_phase)

      Whatsapp::Steps::AskForIdeaService.call(conversation:)
    end

    # Routed through the step service rather than writing the columns here, so
    # the keywords, the recovery button and the assistant cannot drift into
    # leaving the account in three different states.
    def handle_opt_keywords
      if OPT_OUT_KEYWORDS.include?(normalized_text)
        Whatsapp::Steps::SetMessageDeliveryService.disable(conversation:)

        return true
      end

      if OPT_IN_KEYWORDS.include?(normalized_text)
        Whatsapp::Steps::SetMessageDeliveryService.enable(conversation:)

        return true
      end

      false
    end

    # Stores what a QR deep link points at without sending anything, so the
    # caller decides the reply (link invitation first for unlinked numbers).
    # Returns nil, :phase, :projekt or :projekt_without_phase.
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
      eligible_phases = WhatsappEligiblePhasesQuery.call(projekt: projekt)

      return :projekt_without_phase if eligible_phases.empty?

      if eligible_phases.one?
        conversation.start_flow!(eligible_phases.first)
      else
        conversation.reset_flow!
        conversation.merge_context!(
          phase_choice_projekt_id: projekt.id,
          phase_choice_ids: eligible_phases.map(&:id)
        )
      end

      :projekt
    end

    def handle_idea
      idea_text = inbound_text.to_s.strip

      if idea_text.blank?
        return send_recovery(I18n.t("whatsapp.bot.idea_missing"), [:cancel, :menu])
      end

      return if refuse_if_not_permitted

      generate_draft(idea_text)
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

      Whatsapp::Steps::RefuseParticipationService.call(conversation:, reason: permission_problem)

      true
    end

    def handle_draft_decision
      if publish_requested?
        return publish
      end

      if revision_requested?
        conversation.update!(step: "awaiting_revision")

        return Whatsapp::Outbound.text(
          account:,
          body: I18n.t("whatsapp.bot.ask_revision")
        )
      end

      Whatsapp::Steps::PresentDraftService.call(conversation:)
    end

    def handle_revision
      correction = inbound_text.to_s.strip

      if correction.blank?
        return Whatsapp::Outbound.text(account:, body: I18n.t("whatsapp.bot.ask_revision"))
      end

      conversation.update!(revisions_count: conversation.revisions_count + 1)

      generate_draft(revised_idea_text(correction))
    end

    # Revisions are unlimited by design (CON-2908 acceptance criterion), so the
    # abuse guard is a rate limit per conversation, not a cap on rounds.
    def drafting_throttled?
      last_draft_at = conversation.context["last_draft_at"]

      return false if last_draft_at.blank?

      Time.zone.parse(last_draft_at) > DRAFT_INTERVAL.ago
    end

    def send_throttle_notice
      send_recovery(I18n.t("whatsapp.bot.too_fast"), [:cancel, :menu])
    end

    def revised_idea_text(correction)
      [conversation.draft_resource&.ai_idea_text, correction].compact.join("\n\n")
    end

    def generate_draft(idea_text)
      return send_throttle_notice if drafting_throttled?

      conversation.merge_context!(last_draft_at: Time.current.iso8601, last_idea_text: idea_text)

      Whatsapp::Outbound.text(account:, body: I18n.t("whatsapp.bot.drafting"))

      draft_resource =
        Whatsapp::GenerateDraftService.call(conversation:, idea_text: idea_text)

      conversation.update!(draft_resource: draft_resource)

      Whatsapp::Steps::PresentDraftService.call(conversation:)
    rescue StandardError => e
      Rails.logger.error("[Whatsapp] draft generation failed: #{e.class} - #{e.message}")
      Sentry.capture_exception(e, extra: { whatsapp_conversation_id: conversation.id })

      send_recovery(I18n.t("whatsapp.bot.draft_failed"), [:retry, :cancel, :menu])
    end

    def publish
      return if refuse_if_not_permitted

      result = Whatsapp::PublishDraftService.call(conversation:)

      return send_criteria_feedback if result == :criteria_failed

      if result.blank?
        return send_recovery(I18n.t("whatsapp.bot.publish_failed"), [:retry, :cancel, :menu])
      end

      send_publish_confirmation(result)

      conversation.complete_flow!
    end

    def send_criteria_feedback
      conversation.update!(step: "awaiting_revision")
      failed_criterion = conversation.draft_resource.ai_evaluation_result.to_h["failed_criterion"].to_h

      send_recovery(
        I18n.t(
          "whatsapp.bot.criteria_failed",
          criterion: failed_criterion["name"].to_s,
          feedback: failed_criterion["feedback"].to_s
        ),
        [:cancel, :menu]
      )
    end

    # Only proposals can be held back for moderation — an investment has no
    # admin_accepted column, and the web budget flow publishes it outright.
    def send_publish_confirmation(resource)
      copy_key =
        if resource.is_a?(Proposal) && !resource.admin_accepted?
          "whatsapp.bot.published_pending_moderation"
        else
          "whatsapp.bot.published"
        end

      send_recovery(
        I18n.t(copy_key, url: Whatsapp::PublishedResourceUrl.call(resource)),
        [:menu]
      )
    end

    def publish_requested?
      button_reply_id == Whatsapp::Steps::PresentDraftService::PUBLISH_BUTTON_ID ||
        PUBLISH_KEYWORDS.include?(normalized_text)
    end

    def revision_requested?
      button_reply_id == Whatsapp::Steps::PresentDraftService::REVISE_BUTTON_ID ||
        REVISE_KEYWORDS.include?(normalized_text)
    end

    def button_reply_id
      @raw_message.dig("interactive", "button_reply", "id") ||
        @raw_message.dig("button", "payload")
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
        send_recovery(I18n.t("whatsapp.bot.transcription_failed"), [:cancel, :menu])

        return nil
      end

      @whatsapp_message.update!(body: transcript)

      transcript
    end
end
