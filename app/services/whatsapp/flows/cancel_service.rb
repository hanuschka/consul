class Whatsapp::Flows::CancelService < ApplicationService
  # Catalog C21. Aborts the open submission and says so without inviting the
  # citizen anywhere: "message me again whenever you'd like" is the whole reply.
  #
  # Reached only while a flow is open. The same word typed at any other moment
  # is the section E opt-out, and the two are separated in the gate chain rather
  # than here — see ProcessInboundMessageService.
  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    @conversation.reset_flow!

    Whatsapp::Outbound.text(
      account: @conversation.whatsapp_account,
      body: I18n.t("whatsapp.bot.proposal.cancelled")
    )
  end
end
