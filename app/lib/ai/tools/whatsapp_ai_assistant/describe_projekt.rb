class Ai::Tools::WhatsappAiAssistant::DescribeProjekt < Ai::Tools::WhatsappAiAssistant::BaseTool
  # How much of the projekt's page reaches the model. Past this the page stops
  # being a description and becomes a document, and none of the tail answers the
  # question that was asked.
  DESCRIPTION_LENGTH = 1200

  description "Describes one projekt: what it is about in the portal's own words, which phases " \
              "it has, which of them is open for contributions right now, and where to read " \
              "more. Identified by name rather than by id, so it reaches finished projekts as " \
              "well as running ones. Returns facts for you to answer in your own words — it " \
              "sends nothing to the citizen. Answer from what it returned and nothing else; a " \
              "projekt with no text here is one to offer the link for rather than to describe."

  params do
    string :projekt_name, description: "The projekt name as the citizen wrote it"
  end

  def execute(projekt_name:)
    projekt = readable_projekt(projekt_name)

    return unknown_projekt_error(projekt_name) if projekt.blank?

    {
      projekt: projekt_title(projekt),
      subtitle: ::Whatsapp::ProjektCard.subtitle(projekt),
      description: description_of(projekt),
      phases: phases_of(projekt),
      url: projekt_url(projekt)
    }.compact
  end

  private

    # The projekt's own text, flattened and cut, for the model to summarise in its
    # own words. This used to be a second completion — a summariser called from
    # inside this tool, while the turn held the conversation's advisory lock — so a
    # citizen asking about a projekt waited through two model calls for one answer.
    #
    # Handing over the text instead is cheaper and strictly better: the summary is
    # then written with their actual question in view, which a detached summariser
    # never had.
    #
    # Read through Projekt#page_content rather than off the page, because a projekt
    # in content-block mode leaves pages.content empty — reading the column would
    # describe those projekts by their subtitle alone. Content blocks also carry
    # {{projekt_map}}-style placeholders, which are markup rather than text.
    def description_of(projekt)
      ::Whatsapp.plain_text(
        projekt.page_content.to_s.gsub(/\{\{.*?\}\}/, " "), length: DESCRIPTION_LENGTH
      ).presence
    end

    # Every phase a citizen may look at, not only the ones that can be contributed
    # to: a closed phase still holds what happened in it, and that is most of what
    # this tool is asked about.
    #
    # Each row carries the same verdict start_draft will reach, so the model cannot
    # offer a submission into a phase that would refuse it.
    def phases_of(projekt)
      ::Whatsapp::ProjektPhasesQuery.call(projekt: projekt).map do |candidate|
        {
          projekt_phase_id: candidate.id,
          phase: candidate.title,
          ends_on: ::Whatsapp::DatePhrase.absolute(candidate.end_date),
          ends_in: ::Whatsapp::DatePhrase.relative(candidate.end_date),
          open_for_submission: ::Whatsapp::EligiblePhasesQuery.eligible?(candidate)
        }.compact
      end
    end
end
