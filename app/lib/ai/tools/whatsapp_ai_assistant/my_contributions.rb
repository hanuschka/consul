class Ai::Tools::WhatsappAiAssistant::MyContributions < Ai::Tools::WhatsappAiAssistant::BaseTool
  MAX_SHOWN = ::Whatsapp::MAX_LIST_ROWS

  description "Returns what this citizen has submitted themselves, newest first, each with " \
              "whether it is already public or still waiting to be reviewed, and its link where " \
              "it has one. Use it when they ask about their own contributions, what happened to " \
              "what they sent in, or whether something went online. Sends nothing. A proposal " \
              "waiting for review has no public page yet, so say that rather than offering a " \
              "link that would answer with an error."

  def execute
    return not_linked_error("show this citizen their own contributions") if user.blank?

    contributions = ::Whatsapp::UserContributionsQuery.call(user: user)

    {
      total: contributions.size,
      contributions: contributions.first(MAX_SHOWN).map { |resource| row_for(resource) }
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
