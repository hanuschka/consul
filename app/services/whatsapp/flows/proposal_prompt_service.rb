class Whatsapp::Flows::ProposalPromptService < ApplicationService
  # Catalog C13. Names the projekt, which the cold push in section B may not:
  # this is a freeform follow-up inside the 24-hour window, sent because the
  # citizen already wrote in, not the push itself.
  def initialize(conversation:, projekt_phase:)
    @conversation = conversation
    @projekt_phase = projekt_phase
  end

  def call
    @conversation.start_flow!(@projekt_phase)

    Whatsapp::Outbound.buttons(
      account: @conversation.whatsapp_account,
      body: body,
      buttons: buttons
    )
  end

  private

    def body
      I18n.t(
        "whatsapp.bot.proposal.prompt",
        projekt: Whatsapp::ProjektLink.title(@projekt_phase.projekt)
      )
    end

    def buttons
      [
        Whatsapp::FlowActions.button(
          action: :idea_start,
          label_key: "whatsapp.bot.buttons.idea_start",
          param: @projekt_phase.id
        ),
        Whatsapp::FlowActions.button(
          action: :dismiss, label_key: "whatsapp.bot.buttons.no_thanks"
        )
      ]
    end
end
