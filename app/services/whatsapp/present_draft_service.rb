class Whatsapp::PresentDraftService < ApplicationService
  PUBLISH_BUTTON_ID = "whatsapp_publish".freeze
  REVISE_BUTTON_ID = "whatsapp_revise".freeze
  DESCRIPTION_PREVIEW_LENGTH = 700

  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    @conversation.update!(step: "awaiting_draft_decision")

    Whatsapp::SendButtonsService.call(
      account: @conversation.whatsapp_account,
      body: draft_summary,
      buttons: buttons
    )
  end

  private

    def proposal
      @conversation.proposal
    end

    def draft_summary
      I18n.t(
        "whatsapp.bot.draft_summary",
        title: proposal.title,
        description: plain_description
      )
    end

    def plain_description
      ActionController::Base.helpers
        .strip_tags(proposal.description.to_s)
        .squish
        .truncate(DESCRIPTION_PREVIEW_LENGTH)
    end

    def buttons
      [
        { id: PUBLISH_BUTTON_ID, title: I18n.t("whatsapp.bot.buttons.publish") },
        { id: REVISE_BUTTON_ID, title: I18n.t("whatsapp.bot.buttons.revise") }
      ]
    end
end
