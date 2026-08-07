class Ai::Tools::WhatsappAiAssistant::ListMyContributions < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Lists what this citizen has already submitted to the portal — their proposals and " \
              "their budget investments, newest first, with the link to each and to the projekt " \
              "it belongs to. Takes no arguments. Use it to answer questions like what did I " \
              "submit or where can I find my proposal."

  # The same history the menu's contributions row lists, so the two channels
  # cannot answer "what did I submit" differently.
  def execute
    contributions =
      ::WhatsappUserContributionsQuery.call(user: user).map { |resource| row_for(resource) }

    { contributions: contributions }
  end

  private

    def row_for(resource)
      projekt = resource.projekt

      {
        kind: resource.is_a?(::Proposal) ? "proposal" : "budget investment",
        title: resource.title,
        projekt: projekt.present? ? projekt_title(projekt) : nil,
        projekt_url: projekt.present? ? projekt_url(projekt) : nil,
        submitted_on: resource.created_at.to_date.iso8601,
        url: ::Whatsapp::PublishedResourceUrl.call(resource)
      }.compact
    end
end
