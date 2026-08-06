class Whatsapp::ResumeFlowService < ApplicationService
  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    return Whatsapp::AskForIdeaService.call(conversation: @conversation) if
      @conversation.projekt_phase.present?

    return ask_phase_choice if pending_phase_choice?

    Whatsapp::SendTextService.call(
      account: @conversation.whatsapp_account,
      body: I18n.t("whatsapp.bot.no_projekt")
    )
  end

  private

    def pending_phase_choice?
      pending_projekt.present? && pending_phases.many?
    end

    def pending_projekt
      @pending_projekt ||= Projekt.find_by(id: @conversation.context["phase_choice_projekt_id"])
    end

    def pending_phases
      @pending_phases ||=
        ProjektPhase
          .where(id: Array(@conversation.context["phase_choice_ids"]))
          .includes(projekt: :page)
          .to_a
    end

    def ask_phase_choice
      Whatsapp::AskPhaseChoiceService.call(
        conversation: @conversation,
        projekt: pending_projekt,
        projekt_phases: pending_phases
      )
    end
end
