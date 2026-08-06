class Whatsapp::SendRecoveryService < ApplicationService
  # Every dead end offers a way out, so a citizen never has to guess what the
  # bot expects next. Ids are global: they are handled before the step
  # dispatcher, so a button works from whatever state the flow is in.
  ACTION_IDS = {
    retry: "whatsapp_retry",
    cancel: "whatsapp_cancel",
    menu: "whatsapp_menu"
  }.freeze

  MAX_BUTTONS = 3

  def initialize(conversation:, body:, actions:)
    @conversation = conversation
    @body = body
    @actions = actions
  end

  def call
    Whatsapp::SendButtonsService.call(
      account: @conversation.whatsapp_account,
      body: @body,
      buttons: buttons
    )
  end

  def self.action_from(button_reply_id)
    ACTION_IDS.key(button_reply_id.to_s)
  end

  private

    def buttons
      @actions.first(MAX_BUTTONS).map do |action|
        { id: ACTION_IDS.fetch(action), title: I18n.t("whatsapp.bot.buttons.#{action}") }
      end
    end
end
