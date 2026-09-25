class Ai::Tools::WhatsappAiAssistant::MyContributions < Ai::Tools::WhatsappAiAssistant::BaseTool
  MORE_SCOPE = "my_contributions".freeze

  description "Returns what this citizen has submitted themselves, newest first, each with " \
              "whether it is already public or still waiting to be reviewed, its link where it " \
              "has one, and its own action_id. Use it when they ask about their own " \
              "contributions, what happened to what they sent in, or whether something went " \
              "online. Sends nothing. A proposal waiting for review has no public page yet, so " \
              "say that rather than offering a link that would answer with an error. Each " \
              "action_id opens the one contribution it belongs to: pass it to send_list to make " \
              "every row tappable, one row per contribution, never the same id twice. " \
              "#{::Whatsapp::MAX_OFFERED_LIST_ROWS} at a time: where there are more, say how " \
              "many there are altogether and offer more_action_id as a row. Whatever you send, " \
              "the sentence above the list names how many rows it holds — never the total and " \
              "never the number this returned."

  params do
    optional :from, description: FROM_DESCRIPTION do
      integer
    end
  end

  def execute(from: 0)
    return not_linked_error("show this citizen their own contributions") if user.blank?

    query = ::Whatsapp::UserContributionsQuery.new(user: user, from: from)
    contributions = query.call

    {
      contributions: contributions.map { |resource| row_for(resource) },
      **::Whatsapp::ListWindow.report(
        scope: MORE_SCOPE, from: from, shown: contributions.size, total: query.total
      )
    }
  end

  private

    # The action id travels with the row rather than being composed by the model
    # from an id and a kind: a citizen's own history spans proposals and budget
    # investments, and which of the two a row is is exactly what the model cannot
    # see. Without it the only pill it could reach for was the projekt's, which is
    # one id for every row of the list — and a list de-duplicates by id.
    def row_for(resource)
      {
        title: resource.title,
        public: public?(resource),
        url: ::Whatsapp::PublishedResourceUrl.call(resource),
        action_id: ::Whatsapp::ContributionPill.id_for(resource)
      }.compact
    end

    # Only proposals can be held back for moderation — an investment has no
    # admin_accepted column, and the web budget flow publishes it outright.
    def public?(resource)
      return true if !resource.is_a?(::Proposal)

      resource.admin_accepted?
    end
end
