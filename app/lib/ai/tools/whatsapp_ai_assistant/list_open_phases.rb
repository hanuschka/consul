class Ai::Tools::WhatsappAiAssistant::ListOpenPhases < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Lists the participation phases that are currently open for submissions across " \
              "the whole portal. Returns the projekt_phase_id that describe_projekt, " \
              "check_participation_eligibility and start_phase_flow expect. Takes no arguments. " \
              "To show the citizen a tappable list of these phases, call show_menu instead."

  def execute
    { phases: open_projekt_phases.map { |projekt_phase| summary_of(projekt_phase) } }
  end

  private

    def summary_of(projekt_phase)
      {
        projekt_phase_id: projekt_phase.id,
        projekt: projekt_title(projekt_phase.projekt),
        phase: projekt_phase.title,
        ends_on: projekt_phase.end_date&.to_date&.iso8601
      }.compact
    end
end
