class Ai::Tools::WhatsappAiAssistant::DescribeProjekt < Ai::Tools::WhatsappAiAssistant::BaseTool
  SUMMARY_LENGTH = 800

  description "Describes one project: what it is about, which phases it has, which of them is " \
              "open for submissions right now, and where to read more. Identified by name rather " \
              "than by id, so it reaches finished projects as well as running ones. Returns facts " \
              "for you to answer in your own words — it sends nothing to the citizen itself."

  params do
    string :projekt_name, description: "The project name as the citizen wrote it"
  end

  def execute(projekt_name:)
    projekt = readable_projekt(projekt_name)

    return unknown_projekt_error(projekt_name) if projekt.blank?

    {
      projekt: projekt_title(projekt),
      summary: summary_of(projekt),
      phases: phases_of(projekt),
      url: projekt_url(projekt)
    }.compact
  end

  private

    # The same summary the card sends, not the page's own text. This tool used to
    # hand back the subtitle and the opening of the page joined together, which is
    # the one thing a summary may not be — a copy of it: the model then either
    # repeated it verbatim or rewrote editorial prose it had no other account of
    # the projekt to check against. Shared with SendProjektCardService, so the
    # projekt the citizen reads about and the projekt the model reasons about are
    # described in one voice — and cached once for both.
    def summary_of(projekt)
      ::Whatsapp::AiAssistant::ProjektSummaryService.call(
        projekt: projekt, length: SUMMARY_LENGTH
      )
    end

    # Every phase a citizen may look at, not only the ones the bot can submit to:
    # a closed phase still holds what happened in it, and that is most of what
    # this tool is asked about.
    #
    # Each row carries the same verdict start_phase_flow will reach, so the model
    # cannot offer a submission into a phase that would refuse the tap.
    def phases_of(projekt)
      ::Whatsapp::ProjektPhasesQuery.call(projekt: projekt).map do |projekt_phase|
        {
          projekt_phase_id: projekt_phase.id,
          phase: projekt_phase.title,
          ends_on: ::Whatsapp::DatePhrase.absolute(projekt_phase.end_date),
          ends_in: ::Whatsapp::DatePhrase.relative(projekt_phase.end_date),
          open_for_submission: ::Whatsapp::EligiblePhasesQuery.eligible?(projekt_phase)
        }.compact
      end
    end
end
