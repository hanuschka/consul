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

    conversation.update!(last_inbound_at: Time.current)

    return if handle_opt_keywords
    return if account.opt_out_at.present?
    return if @whatsapp_message.audio? && inbound_text.blank?

    phase_token_captured = capture_phase_token

    return Whatsapp::SendLinkInvitationService.call(conversation:) if account.user.blank?
    return Whatsapp::AskForIdeaService.call(conversation:) if phase_token_captured

    dispatch_step
  end

  private

    def account
      @account ||= @whatsapp_message.whatsapp_account
    end

    def conversation
      @conversation ||= account.conversation
    end

    def dispatch_step
      case conversation.step
      when "awaiting_idea"
        handle_idea
      when "awaiting_draft_decision"
        handle_draft_decision
      when "awaiting_revision"
        handle_revision
      else
        Whatsapp::AskForIdeaService.call(conversation:)
      end
    end

    def handle_opt_keywords
      if OPT_OUT_KEYWORDS.include?(normalized_text)
        account.update!(opt_out_at: Time.current)
        conversation.reset_flow!
        Whatsapp::SendTextService.call(account:, body: I18n.t("whatsapp.bot.opted_out"))

        return true
      end

      if OPT_IN_KEYWORDS.include?(normalized_text)
        account.update!(opt_in_at: Time.current, opt_out_at: nil)
        Whatsapp::SendTextService.call(account:, body: I18n.t("whatsapp.bot.opted_in"))

        return true
      end

      false
    end

    # Returns true when the message carried a valid deep-link token, so the
    # caller can prompt for the idea instead of treating the token text as one.
    def capture_phase_token
      projekt_phase_id = Whatsapp::PhaseTokenService.projekt_phase_id_from(inbound_text)

      return false if projekt_phase_id.blank?

      projekt_phase = ProjektPhase.find_by(id: projekt_phase_id)

      return false if projekt_phase.blank?

      conversation.start_flow!(projekt_phase)

      true
    end

    def handle_idea
      idea_text = inbound_text.to_s.strip

      if idea_text.blank?
        return Whatsapp::SendTextService.call(account:, body: I18n.t("whatsapp.bot.idea_missing"))
      end

      permission_problem =
        Whatsapp::ProposalPermissionService.call(
          projekt_phase: conversation.projekt_phase,
          user: account.user
        )

      if permission_problem.present?
        return Whatsapp::RefuseParticipationService.call(conversation:, reason: permission_problem)
      end

      generate_draft(idea_text)
    end

    def handle_draft_decision
      if publish_requested?
        return publish
      end

      if revision_requested?
        conversation.update!(step: "awaiting_revision")

        return Whatsapp::SendTextService.call(
          account:,
          body: I18n.t("whatsapp.bot.ask_revision")
        )
      end

      Whatsapp::PresentDraftService.call(conversation:)
    end

    def handle_revision
      correction = inbound_text.to_s.strip

      if correction.blank?
        return Whatsapp::SendTextService.call(account:, body: I18n.t("whatsapp.bot.ask_revision"))
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
      Whatsapp::SendTextService.call(account:, body: I18n.t("whatsapp.bot.too_fast"))
    end

    def revised_idea_text(correction)
      [conversation.proposal&.ai_idea_text, correction].compact.join("\n\n")
    end

    def generate_draft(idea_text)
      return send_throttle_notice if drafting_throttled?

      conversation.merge_context!(last_draft_at: Time.current.iso8601)

      Whatsapp::SendTextService.call(account:, body: I18n.t("whatsapp.bot.drafting"))

      proposal =
        Whatsapp::GenerateProposalDraftService.call(conversation:, idea_text: idea_text)

      conversation.update!(proposal: proposal)

      Whatsapp::PresentDraftService.call(conversation:)
    rescue StandardError => e
      Rails.logger.error("[Whatsapp] draft generation failed: #{e.class} - #{e.message}")
      Sentry.capture_exception(e, extra: { whatsapp_conversation_id: conversation.id })

      Whatsapp::SendTextService.call(account:, body: I18n.t("whatsapp.bot.draft_failed"))
    end

    def publish
      permission_problem =
        Whatsapp::ProposalPermissionService.call(
          projekt_phase: conversation.projekt_phase,
          user: account.user
        )

      if permission_problem.present?
        return Whatsapp::RefuseParticipationService.call(conversation:, reason: permission_problem)
      end

      result = Whatsapp::PublishProposalService.call(conversation:)

      return send_criteria_feedback if result == :criteria_failed

      if result.blank?
        return Whatsapp::SendTextService.call(account:, body: I18n.t("whatsapp.bot.publish_failed"))
      end

      send_publish_confirmation(result)

      conversation.complete_flow!
    end

    def send_criteria_feedback
      conversation.update!(step: "awaiting_revision")
      failed_criterion = conversation.proposal.ai_evaluation_result.to_h["failed_criterion"].to_h

      Whatsapp::SendTextService.call(
        account:,
        body: I18n.t(
          "whatsapp.bot.criteria_failed",
          criterion: failed_criterion["name"].to_s,
          feedback: failed_criterion["feedback"].to_s
        )
      )
    end

    def send_publish_confirmation(proposal)
      copy_key =
        if proposal.admin_accepted?
          "whatsapp.bot.published"
        else
          "whatsapp.bot.published_pending_moderation"
        end

      Whatsapp::SendTextService.call(
        account:,
        body: I18n.t(copy_key, url: proposal_url(proposal))
      )
    end

    def proposal_url(proposal)
      Rails.application.routes.url_helpers.proposal_url(proposal, **UrlOptions.default.to_h)
    end

    def publish_requested?
      button_reply_id == Whatsapp::PresentDraftService::PUBLISH_BUTTON_ID ||
        PUBLISH_KEYWORDS.include?(normalized_text)
    end

    def revision_requested?
      button_reply_id == Whatsapp::PresentDraftService::REVISE_BUTTON_ID ||
        REVISE_KEYWORDS.include?(normalized_text)
    end

    def button_reply_id
      @raw_message.dig("interactive", "button_reply", "id") ||
        @raw_message.dig("button", "payload")
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
        Whatsapp::SendTextService.call(account:, body: I18n.t("whatsapp.bot.transcription_failed"))

        return nil
      end

      @whatsapp_message.update!(body: transcript)

      transcript
    end
end
