class Ai::Tools::WhatsappAiAssistant::DescribeProjekt < Ai::Tools::WhatsappAiAssistant::BaseTool
  SUMMARY_LENGTH = 800

  description "Describes the projekt behind an open participation phase: what it is about, when " \
              "the phase ends and where to read more. Identified by projekt_phase_id because " \
              "that is the id list_open_phases returns."

  params do
    integer :projekt_phase_id, description: "Id of an open participation phase"
  end

  def execute(projekt_phase_id:)
    projekt_phase = eligible_phase(projekt_phase_id)

    return unknown_phase_error if projekt_phase.blank?

    {
      projekt: projekt_title(projekt_phase.projekt),
      phase: projekt_phase.title,
      ends_on: projekt_phase.end_date&.to_date&.iso8601,
      summary: summary_of(projekt_phase.projekt),
      url: projekt_url(projekt_phase.projekt)
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
end
