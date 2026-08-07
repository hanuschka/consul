class Whatsapp::Flows::AskImageService < ApplicationService
  # Asked once the draft has been confirmed and before anything is published: a
  # picture is offered, never assumed. Three pills is exactly WhatsApp's limit,
  # which is also why "skip" is a button rather than an implied timeout — a
  # citizen who wants no picture must be able to say so in one tap.
  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    @conversation.update!(step: "awaiting_image_choice")

    Whatsapp::Outbound.buttons(
      account: @conversation.whatsapp_account,
      body: I18n.t("whatsapp.bot.proposal.ask_image"),
      buttons: buttons
    )
  end

  private

    def buttons
      [
        Whatsapp::FlowActions.button(
          action: :image_upload, label_key: "whatsapp.bot.buttons.image_upload"
        ),
        Whatsapp::FlowActions.button(
          action: :image_generate, label_key: "whatsapp.bot.buttons.image_generate"
        ),
        Whatsapp::FlowActions.button(
          action: :image_skip, label_key: "whatsapp.bot.buttons.image_skip"
        )
      ]
    end
end
