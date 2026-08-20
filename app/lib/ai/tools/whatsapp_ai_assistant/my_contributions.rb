class Ai::Tools::WhatsappAiAssistant::MyContributions < Ai::Tools::WhatsappAiAssistant::BaseTool
  MORE_SCOPE = "my_contributions".freeze

  description "Returns what this citizen has submitted themselves, newest first, each with " \
              "whether it is already public or still waiting to be reviewed, and its link where " \
              "it has one. Use it when they ask about their own contributions, what happened to " \
              "what they sent in, or whether something went online. Sends nothing. A proposal " \
              "waiting for review has no public page yet, so say that rather than offering a " \
              "link that would answer with an error. Ten at a time: where there are more, say " \
              "how many and offer more_action_id as a button."

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

    def row_for(resource)
      {
        title: resource.title,
        public: public?(resource),
        url: ::Whatsapp::PublishedResourceUrl.call(resource)
      }.compact
    end

    # Only proposals can be held back for moderation — an investment has no
    # admin_accepted column, and the web budget flow publishes it outright.
    def public?(resource)
      return true if !resource.is_a?(::Proposal)

      resource.admin_accepted?
    end
end
