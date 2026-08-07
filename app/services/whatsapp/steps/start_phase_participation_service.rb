class Whatsapp::Steps::StartPhaseParticipationService < ApplicationService
  # The phase menu offers this row only when the citizen may take part, but the
  # tap can arrive long after the row was sent, so entering the flow re-asks the
  # same question AskForIdeaService would.
  def initialize(conversation:, projekt_phase:)
    @conversation = conversation
    @projekt_phase = projekt_phase
  end

  def call
    return refuse if !bot_can_submit_to_phase?

    @conversation.start_flow!(@projekt_phase)

    Whatsapp::Steps::AskForIdeaService.call(conversation: @conversation)
  end

  private

    def bot_can_submit_to_phase?
      WhatsappEligiblePhasesQuery.eligible?(@projekt_phase)
    end

    # A phase the bot has no flow for is not a refusal about this citizen, so it
    # points at the page where taking part is still possible.
    def refuse
      Whatsapp::Outbound.recovery(
        conversation: @conversation,
        body: I18n.t(
          "whatsapp.bot.menu.phase_participation.unsupported",
          url: Whatsapp::ProjektLink.phase_url(@projekt_phase)
        ),
        actions: [:menu]
      )
    end
end
