class Ai::Tools::WhatsappAiAssistant::ListProjektContributions <
  Ai::Tools::WhatsappAiAssistant::BaseTool
  # What other people have submitted to one projekt. A read now rather than a
  # sender: it used to build its own list message, which made it the same tool
  # twice over — a query, and a hardcoded rendering of the query. The rendering is
  # send_list's, and what goes in the rows is the model's.
  MAX_SHOWN = ::Whatsapp::MAX_OFFERED_LIST_ROWS

  description "Returns what other people have already submitted to one projekt — its published " \
              "proposals and budget investments, newest first, each with its age, the link to " \
              "open it and its own action_id. Use it for questions like what have people " \
              "suggested or what is already in there. These are everyone's contributions, not " \
              "this citizen's own — that is my_contributions. Sends nothing: name a few of them " \
              "in your reply. Each action_id opens the one contribution it belongs to, so a " \
              "wish to look through them is send_list with one row per contribution, never the " \
              "same id twice, and a sentence naming how many rows it holds; a single one they " \
              "have already picked is send_link."

  params do
    string :projekt_name, description: "The projekt name as the citizen wrote it"
  end

  def execute(projekt_name:)
    projekt = readable_projekt(projekt_name)

    return unknown_projekt_error(projekt_name) if projekt.blank?

    contributions = ::Whatsapp::ProjektContributionsQuery.call(projekt: projekt)

    {
      projekt: projekt_title(projekt),
      total: contributions.size,
      contributions: contributions.first(MAX_SHOWN).map { |entry| row_for(entry) }
    }
  end

  private

    def row_for(entry)
      {
        title: entry[:title],
        submitted: ::Whatsapp::DatePhrase.relative(entry[:created_at]),
        url: entry[:url],
        action_id: entry[:action_id]
      }.compact
    end
end
