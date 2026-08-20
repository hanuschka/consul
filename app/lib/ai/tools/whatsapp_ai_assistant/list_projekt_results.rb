class Ai::Tools::WhatsappAiAssistant::ListProjektResults < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Lists the participation phases whose results the portal has published — what came " \
              "out of them — each with the link that opens the result. Name a project to get only " \
              "its results, or pass null for the whole portal. Use it for questions like what " \
              "came of this, what was decided, or what the outcome was. Returns facts for you to " \
              "answer in your own words — it sends nothing to the citizen itself. Ten at a time: " \
              "where there are more, say how many and offer more_action_id as a button."

  MORE_SCOPE = "results".freeze

  params do
    optional :projekt_name,
      description: "The project name as the citizen wrote it, or null for the whole portal" do
      string
    end
    optional :from, description: FROM_DESCRIPTION do
      integer
    end
  end

  def execute(projekt_name: nil, from: 0)
    for_named_projekt(projekt_name) do |projekt|
      query = ::Whatsapp::PublishedResultsQuery.new(projekt: projekt, from: from)
      projekt_phases = query.call

      {
        results: projekt_phases.map { |projekt_phase| row_for(projekt_phase) },
        **::Whatsapp::ListWindow.report(
          scope: MORE_SCOPE, from: from, shown: projekt_phases.size, total: query.total
        )
      }
    end
  end

  private

    # The phase names the row rather than the projekt: a projekt with several
    # evaluated phases would otherwise return the same title several times over
    # with nothing to tell the rows apart.
    #
    # Linked through evaluation_url rather than the projekt's own address, which
    # opens the page without the tab the result lives in.
    def row_for(projekt_phase)
      {
        projekt: projekt_title(projekt_phase.projekt),
        phase: projekt_phase.title,
        ended_on: ::Whatsapp::DatePhrase.absolute(projekt_phase.end_date),
        ended_ago: ::Whatsapp::DatePhrase.relative(projekt_phase.end_date),
        url: ::Whatsapp::ProjektLink.evaluation_url(projekt_phase)
      }.compact
    end
end
