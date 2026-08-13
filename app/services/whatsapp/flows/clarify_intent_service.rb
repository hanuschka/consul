class Whatsapp::Flows::ClarifyIntentService < Whatsapp::Flows::BaseService
  # Catalog C20. The one reply for "I read that, but I cannot tell what you
  # want". Deliberately names the two things it could have been rather than
  # asking the citizen to rephrase blindly.
  def call
    Whatsapp::Outbound.text(
      account: account,
      body: Whatsapp.phrase("whatsapp.bot.proposal.unclear")
    )
  end
end
