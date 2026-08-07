class Whatsapp::Flows::BuildDraftService < ApplicationService
  # Everything between "the citizen sent an idea" and "the draft card is on
  # screen": the rate guard, the generation call, and the one branch the catalog
  # adds — asking for a category when the drafting model did not choose one.
  #
  # Revisions are unlimited by design, so the abuse guard is a rate limit per
  # conversation rather than a cap on rounds.
  DRAFT_INTERVAL = 15.seconds

  # Two entry points rather than one with a flag: the only thing that differs is
  # which copy the finished card carries, and a caller reading
  # `BuildDraftService.call(..., true)` could not tell you which.
  def self.from_idea(conversation:, idea_text:)
    new(conversation: conversation, idea_text: idea_text, copy: :first).call
  end

  def self.from_revision(conversation:, idea_text:)
    new(conversation: conversation, idea_text: idea_text, copy: :revised).call
  end

  def initialize(conversation:, idea_text:, copy: :first)
    @conversation = conversation
    @idea_text = idea_text
    @copy = copy
  end

  def call
    return send_throttle_notice if throttled?

    @conversation.merge_context!(
      last_draft_at: Time.current.iso8601, last_idea_text: @idea_text
    )

    Whatsapp::Outbound.text(account: account, body: I18n.t("whatsapp.bot.drafting"))

    @conversation.update!(draft_resource: generate)

    present
  rescue StandardError => e
    report(e)

    Whatsapp::Outbound.recovery(
      conversation: @conversation,
      body: I18n.t("whatsapp.bot.draft_failed"),
      actions: [:retry, :cancel]
    )
  end

  private

    def account
      @conversation.whatsapp_account
    end

    def generate
      Whatsapp::GenerateDraftService.call(conversation: @conversation, idea_text: @idea_text)
    end

    # Asked only when the phase offers categories and the draft came back
    # without one. The model is handed the same categories as a closed enum in
    # the generation call, so this is the exception rather than a step.
    def present
      return Whatsapp::Flows::AskCategoryService.call(conversation: @conversation) if ask_category?
      return Whatsapp::Flows::PresentDraftService.revised_draft(conversation: @conversation) if
        @copy == :revised

      Whatsapp::Flows::PresentDraftService.first_draft(conversation: @conversation)
    end

    def ask_category?
      return false if Whatsapp::DraftCategory.label_for(@conversation.draft_resource).present?

      Whatsapp::DraftCategory.available?(@conversation.projekt_phase)
    end

    def throttled?
      last_draft_at = @conversation.context["last_draft_at"]

      return false if last_draft_at.blank?

      Time.zone.parse(last_draft_at) > DRAFT_INTERVAL.ago
    end

    def send_throttle_notice
      Whatsapp::Outbound.recovery(
        conversation: @conversation,
        body: I18n.t("whatsapp.bot.too_fast"),
        actions: [:cancel]
      )
    end

    def report(exception)
      Rails.logger.error("[Whatsapp] draft generation failed: #{exception.class} - #{exception.message}")
      Sentry.capture_exception(exception, extra: { whatsapp_conversation_id: @conversation.id })
    end
end
