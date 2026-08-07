class Whatsapp::Flows::ClarifyIntentService < ApplicationService
  # Catalog C20. The one reply for "I read that, but I cannot tell what you
  # want". Deliberately names the two things it could have been rather than
  # asking the citizen to rephrase blindly.
  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    Whatsapp::Outbound.text(
      account: @conversation.whatsapp_account,
      body: I18n.t("whatsapp.bot.proposal.unclear")
    )
  end
end
