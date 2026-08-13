class Ai::Tools::WhatsappAiAssistant::ListOpenPhases < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Lists the participation phases that are currently open for submissions across " \
              "the whole portal, each with the link to its projekt. Returns the " \
              "projekt_phase_id that describe_projekt, check_participation_eligibility and " \
              "start_phase_flow expect. Takes no arguments. When shown is less than total_open " \
              "the rest are not in the list at all: ask the citizen which project they mean and " \
              "pass it to start_proposal_submission rather than answering from what you see. To " \
              "show the citizen a tappable list of these phases, call show_projekts instead."

  # Capped at what a WhatsApp list holds, because the phases named here are the
  # ones the citizen is offered next. The total is reported alongside so a
  # truncation is never read as "this is everything that is open" — the model
  # cannot tell the difference from the rows alone, and would answer "ten projekts
  # are running" on a portal with forty.
  def execute
    phases = open_projekt_phases

    {
      phases: phases.map { |projekt_phase| summary_of(projekt_phase) },
      shown: phases.size,
      total_open: all_open_projekt_phases.size
    }
  end

  private

    def summary_of(projekt_phase)
      {
        projekt_phase_id: projekt_phase.id,
        projekt: projekt_title(projekt_phase.projekt),
        phase: projekt_phase.title,
        ends_on: projekt_phase.end_date&.to_date&.iso8601,
        url: projekt_url(projekt_phase.projekt)
      }.compact
    end
end
