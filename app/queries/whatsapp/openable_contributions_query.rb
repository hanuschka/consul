class Whatsapp::OpenableContributionsQuery < ApplicationQuery
  # What a citizen could mean when they name a Beitrag they want to open. Both
  # kinds a projekt holds are searched, not proposals alone: a budget investment
  # is a Beitrag to the citizen who wrote it, and the projekt's own contribution
  # list already links investments — answering "no publicly listed proposal
  # matches" to an investment's title refuses on the strength of our table names.
  #
  # Searched through the portal's own index per model rather than by matching a
  # title column; see Whatsapp::SupportableProposalsQuery for why. Merged on
  # supports, the one rank the two share: a tsearch score is relative to its own
  # query over its own table and means nothing next to the other's.
  #
  # Deliberately few results: this feeds a chat reply, and a citizen scanning
  # eight near-identical titles on a phone will pick the wrong one.
  MAX_RESULTS = 3

  def initialize(text:)
    @text = text.to_s.strip
  end

  def call
    return [] if @text.blank?

    (proposals + investments)
      .sort_by { |contribution| -contribution.cached_votes_up.to_i }
      .first(MAX_RESULTS)
  end

  private

    def proposals
      Proposal.base_selection.search(@text).limit(MAX_RESULTS).to_a
    end

    # not_unfeasible is what the portal itself lists, and acts_as_paranoid on
    # hidden_at answers the rest. Ordered explicitly because Investment.search
    # re-queries by id and drops the ranking with it, which would otherwise make
    # the three that survive the limit arbitrary.
    def investments
      Budget::Investment
        .not_unfeasible
        .search(@text)
        .includes(:budget)
        .order(cached_votes_up: :desc)
        .limit(MAX_RESULTS)
        .to_a
    end
end
