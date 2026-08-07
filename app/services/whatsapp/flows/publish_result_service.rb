class Whatsapp::Flows::PublishResultService < ApplicationService
  # Catalog C19. Three outcomes, decided by the phase's own moderation setting
  # rather than by anything the bot knows: published with its link, held for
  # review, or refused because the phase's hard criteria rejected it.
  #
  # Lifted out of ProcessInboundMessageService so the gate chain stays a
  # dispatcher and the thing that decides what a citizen is told about their
  # submission lives in one readable place.
  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    result = Whatsapp::PublishDraftService.call(conversation: @conversation)

    return send_criteria_feedback if result == :criteria_failed
    return send_failure if result.blank?

    send_confirmation(result)

    @conversation.complete_flow!
  end

  private

    def account
      @conversation.whatsapp_account
    end

    # Only proposals can be held back for moderation — an investment has no
    # admin_accepted column, and the web budget flow publishes it outright.
    def send_confirmation(resource)
      return send_pending if resource.is_a?(Proposal) && !resource.admin_accepted?

      Whatsapp::Outbound.text(
        account: account,
        body: I18n.t(
          "whatsapp.bot.proposal.published",
          url: Whatsapp::PublishedResourceUrl.call(resource)
        )
      )
    end

    def send_pending
      Whatsapp::Outbound.text(
        account: account,
        body: I18n.t("whatsapp.bot.proposal.published_pending_moderation")
      )
    end

    def send_failure
      Whatsapp::Outbound.recovery(
        conversation: @conversation,
        body: I18n.t("whatsapp.bot.publish_failed"),
        actions: [:retry, :cancel]
      )
    end

    # The phase's hard criteria are the portal's own rules, not a safety filter,
    # so the citizen is told which one failed and left in the revision step with
    # the draft intact.
    def send_criteria_feedback
      @conversation.update!(step: "awaiting_revision")

      failed_criterion =
        @conversation.draft_resource.ai_evaluation_result.to_h["failed_criterion"].to_h

      Whatsapp::Outbound.recovery(
        conversation: @conversation,
        body: I18n.t(
          "whatsapp.bot.criteria_failed",
          criterion: failed_criterion["name"].to_s,
          feedback: failed_criterion["feedback"].to_s
        ),
        actions: [:cancel]
      )
    end
end
