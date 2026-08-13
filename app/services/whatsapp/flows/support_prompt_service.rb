class Whatsapp::Flows::SupportPromptService < Whatsapp::Flows::BaseService
  # Catalog D24. The proposal id is written into the conversation as well as
  # into the pill, because the citizen may answer in words rather than tapping —
  # "yes" has to reach the same proposal the pill would have.
  def initialize(conversation:, proposal:)
    super(conversation: conversation)
    @proposal = proposal
  end

  def call
    @conversation.merge_context!(support_proposal_id: @proposal.id)

    Whatsapp::Outbound.buttons(
      account: account,
      body: Whatsapp.phrase("whatsapp.bot.support.prompt", title: @proposal.title),
      buttons: buttons
    )
  end

  private

    def buttons
      [
        Whatsapp::FlowActions.button(
          action: :support, label_key: "whatsapp.bot.buttons.support", param: @proposal.id
        ),
        Whatsapp::FlowActions.button(
          action: :dismiss, label_key: "whatsapp.bot.buttons.no_thanks"
        )
      ]
    end
end
