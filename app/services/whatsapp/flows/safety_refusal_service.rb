class Whatsapp::Flows::SafetyRefusalService < ApplicationService
  # Catalog C22. Refuses the text without quoting it back and without accusing
  # anyone: the offer to rephrase is the whole reply, and the flow stays open so
  # rephrasing is the obvious next thing to do.
  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    Whatsapp::Outbound.text(
      account: @conversation.whatsapp_account,
      body: I18n.t("whatsapp.bot.proposal.unsafe")
    )
  end
end
