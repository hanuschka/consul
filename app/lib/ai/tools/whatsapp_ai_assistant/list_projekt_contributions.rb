class Ai::Tools::WhatsappAiAssistant::ListProjektContributions <
  Ai::Tools::WhatsappAiAssistant::BaseTool

  description "Lists what other citizens have already submitted to one project — its published " \
              "proposals and budget investments, newest first, with the link to each. Use it for " \
              "questions like what have people suggested or what is already in there. These are " \
              "everyone's contributions, not this citizen's own. Returns facts for you to answer " \
              "in your own words — it sends nothing to the citizen itself."

  params do
    string :projekt_name, description: "The project name as the citizen wrote it"
  end

  def execute(projekt_name:)
    projekt = readable_projekt(projekt_name)

    return unknown_projekt_error if projekt.blank?

    { contributions: ::Whatsapp::ProjektContributionsQuery.call(projekt: projekt).map { |row| row_for(row) }}
  end

  private

    # The query builds its rows for a WhatsApp list, where the date is the row's
    # subtitle. Renamed on the way out because what reaches the model is read as
    # a fact rather than rendered, and "description" would invite it to repeat
    # the date as if it were the proposal's text.
    def row_for(contribution)
      {
        title: contribution[:title],
        submitted_on: contribution[:created_at].to_date.iso8601,
        url: contribution[:url]
      }.compact
    end
end
