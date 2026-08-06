class Whatsapp::SendEntryMenuService < ApplicationService
  # The portal-wide entry point: what someone gets when no QR token told us
  # which projekt they mean — a first chat opening, a cleared prefill, or a
  # number saved and written to weeks later.
  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    projekt_phases = WhatsappEligiblePhasesQuery.call

    return send_nothing_open if projekt_phases.empty?
    return start_single_phase(projekt_phases.first) if projekt_phases.one?

    @conversation.reset_flow!

    Whatsapp::AskPhaseChoiceService.call(
      conversation: @conversation,
      projekt_phases: projekt_phases
    )
  end

  private

    # With one open phase there is nothing to choose, so the menu is skipped in
    # favour of the question that would follow it anyway.
    def start_single_phase(projekt_phase)
      @conversation.start_flow!(projekt_phase)

      Whatsapp::AskForIdeaService.call(conversation: @conversation)
    end

    # The menu button is still worth offering: a phase may open later, and
    # tapping it is how someone re-checks without composing a message.
    def send_nothing_open
      Whatsapp::SendRecoveryService.call(
        conversation: @conversation,
        body: I18n.t("whatsapp.bot.no_projekt"),
        actions: [:menu]
      )
    end
end
