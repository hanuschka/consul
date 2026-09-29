class Ai::Tools::WhatsappAiAssistant::ListOpenPhases < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Lists the participation phases that are currently open for submissions across " \
              "the whole portal, each with the link to its projekt. Not the answer to a general " \
              "wish to take part — a phase named without its projekt says nothing about what it " \
              "is for, so that is list_open_projekts. This is for a question actually asked " \
              "portal-wide — \"was ist gerade überall offen?\" — and for the phases of a projekt " \
              "already picked, where describe_projekt is the narrower answer. Returns the " \
              "projekt_phase_id that describe_projekt, check_participation_eligibility and " \
              "start_draft expect. Phases sharing a name are told apart by their dates and by " \
              "what they are about, never by a number. " \
              "Say how many there are altogether and name the ones that fit this moment, so " \
              "the rest are one tap away rather than absent. #{MORE_ROWS_HINT}"

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
        about: phase_about(projekt_phase),
        starts_on: ::Whatsapp::DatePhrase.absolute(projekt_phase.start_date),
        ends_on: ::Whatsapp::DatePhrase.absolute(projekt_phase.end_date),
        ends_in: ::Whatsapp::DatePhrase.relative(projekt_phase.end_date),
        url: projekt_url(projekt_phase.projekt)
      }.compact
    end
end
