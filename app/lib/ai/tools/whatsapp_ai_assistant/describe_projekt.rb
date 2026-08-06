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

    # The page content is editorial HTML of any length, so what reaches the
    # model is the readable opening of it rather than the whole document.
    def summary_of(projekt)
      page = projekt.page

      return if page.blank?

      text = [page.subtitle, ActionController::Base.helpers.strip_tags(page.content.to_s)]
        .compact_blank
        .join("\n\n")
        .squish

      text.presence&.truncate(SUMMARY_LENGTH)
    end
end
