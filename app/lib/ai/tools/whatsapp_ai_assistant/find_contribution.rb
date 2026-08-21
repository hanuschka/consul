class Ai::Tools::WhatsappAiAssistant::FindContribution < Ai::Tools::WhatsappAiAssistant::BaseTool
  # One contribution resolved from what the citizen called it, for every tool that
  # then acts on it: opening it, supporting it, commenting on it. One search rather
  # than one per verb, because the citizen names it the same way whichever they mean
  # — and a single match is remembered on the conversation so the state the
  # assistant is told says which contribution the conversation is about.
  description "Finds the contribution a citizen is talking about from what they called it, " \
              "however roughly. Returns its id, its title, how many supports it has, whether it " \
              "can be supported and the link to open it — or several candidates when more than " \
              "one matches, so you can ask which they mean rather than guessing. Call it before " \
              "support_proposal, draft_comment or send_link for a contribution; each of " \
              "those needs the id this returns. Sends nothing."

  params do
    string :title, description: "What the citizen called the contribution, in their own words"
  end

  def execute(title:)
    matches = ::Whatsapp::OpenableContributionsQuery.call(text: title)

    return no_contribution_match_error(title) if matches.empty?
    return { candidates: matches.map { |match| summary_for(match) }} if matches.size > 1

    remember(matches.first)

    { contribution: summary_for(matches.first) }
  end

  private

    # Remembered only when the search was certain. Written under both keys because
    # supporting and commenting each read their own, and which of the two the citizen
    # will ask for is not knowable yet.
    def remember(contribution)
      return if !contribution.is_a?(::Proposal)

      conversation.store_support_proposal_id!(contribution.id)
      conversation.store_comment_proposal_id!(contribution.id)
    end

    # Supporting a budget investment is budget voting rather than a support click, so
    # only proposals report as supportable — the same distinction the two searches
    # behind this used to encode by being two searches.
    def summary_for(contribution)
      contribution_candidate_summary(contribution).merge(
        supportable: contribution.is_a?(::Proposal),
        url: ::Whatsapp::PublishedResourceUrl.call(contribution)
      ).compact
    end
end
