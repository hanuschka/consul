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

    return unknown_projekt_error if projekt.blank?

    {
      projekt: projekt_title(projekt),
      summary: summary_of(projekt),
      phases: phases_of(projekt),
      url: projekt_url(projekt)
    }.compact
  end

  private

    # Read through Projekt#page_content rather than off the page: a projekt in
    # content-block mode leaves pages.content empty, and reading the column
    # directly described every modern projekt as having nothing to say.
    #
    # The result is editorial HTML of any length, so what reaches the model is
    # the readable opening of it rather than the whole document.
    def summary_of(projekt)
      return if projekt.page.blank?

      text = [projekt.page.subtitle, strip_markup(projekt.page_content)]
        .compact_blank
        .join("\n\n")
        .squish

      text.presence&.truncate(SUMMARY_LENGTH)
    end

    # Content blocks carry {{projekt_map}}-style placeholders the page expands
    # at render time. Left in, the model reads them as text and can repeat one
    # at a citizen.
    def strip_markup(content)
      ActionController::Base.helpers.strip_tags(content.to_s).gsub(/\{\{.*?\}\}/, " ")
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
          ends_on: projekt_phase.end_date&.to_date&.iso8601,
          open_for_submission: ::Whatsapp::EligiblePhasesQuery.eligible?(projekt_phase)
        }.compact
      end
    end
end
