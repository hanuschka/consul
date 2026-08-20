class Ai::Tools::WhatsappAiAssistant::ListOpenPhases < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Lists the participation phases that are currently open for submissions across " \
              "the whole portal, each with the link to its projekt. Returns the " \
              "projekt_phase_id that describe_projekt, check_participation_eligibility and " \
              "start_draft expect. Ten at a time: say how many there are altogether, name " \
              "the ones that fit this moment, and offer more_action_id as a button so the rest " \
              "are one tap away rather than absent."

  MORE_SCOPE = "eligible_phases".freeze

  params do
    optional :from, description: FROM_DESCRIPTION do
      integer
    end
  end

  # Capped at what a WhatsApp list holds, because the phases named here are the
  # ones the citizen is offered next. The total is reported alongside so a
  # truncation is never read as "this is everything that is open" — the model
  # cannot tell the difference from the rows alone, and would answer "ten projekts
  # are running" on a portal with forty.
  def execute(from: 0)
    phases = open_projekt_phases(from: from)

    {
      phases: phases.map { |projekt_phase| summary_of(projekt_phase) },
      **::Whatsapp::ListWindow.report(
        scope: MORE_SCOPE, from: from, shown: phases.size, total: all_open_projekt_phases.size
      )
    }
  end

  private

    def summary_of(projekt_phase)
      {
        projekt_phase_id: projekt_phase.id,
        projekt: projekt_title(projekt_phase.projekt),
        phase: projekt_phase.title,
        ends_on: ::Whatsapp::DatePhrase.absolute(projekt_phase.end_date),
        ends_in: ::Whatsapp::DatePhrase.relative(projekt_phase.end_date),
        url: projekt_url(projekt_phase.projekt)
      }.compact
    end
end
