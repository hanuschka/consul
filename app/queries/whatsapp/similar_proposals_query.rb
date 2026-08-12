class Whatsapp::SimilarProposalsQuery < ApplicationQuery
  # Proposals in this phase that may already be the idea a citizen is about to
  # write. base_selection is the portal's own definition of a publicly listed
  # proposal — published, not archived, not retired, admin-accepted — which is
  # also exactly the set that can be supported.
  #
  # Scoped to the one phase rather than portal-wide: the offer this feeds is
  # "support that one instead", and a proposal in a phase the citizen did not
  # choose is not the same participation.
  #
  # Wider than what is ever shown. The portal's index ranks on word overlap, so
  # it answers "same topic" — every playground proposal matches "Spielplatz
  # sanieren". The ranking step behind this one needs candidates to choose
  # from, and decides which of them are the same request.
  CANDIDATE_LIMIT = 10

  # Under any-word matching the query is one OR per term, so an unbounded
  # paragraph becomes a fifty-branch statement that is re-parsed on every
  # message and sweeps a large fraction of the table to build a ranking the
  # limit then throws most of away.
  #
  # Capped by count alone, taking the words as written. Filtering by length
  # looks tempting and is wrong: the most distinctive tokens are often the
  # shortest — a house number, "ÖT", a line name — and dropping them loses
  # exactly the proposals worth finding. Stopwords left in cost nothing at
  # match time, because the dictionary reduces them to empty lexemes.
  MAX_TERMS = 20

  def initialize(projekt_phase:, text:)
    @projekt_phase = projekt_phase
    @text = text.to_s.strip
  end

  def call
    return [] if @projekt_phase.blank?
    return [] if search_terms.blank?

    # Not `search`, which is the search box's question and ANDs every token of
    # it. What is matched here was never typed into a box: it is the citizen's
    # whole idea, and no proposal contains all fifteen words of a paragraph. The
    # strict scope would answer nothing at all, every time, silently.
    #
    # Translations are preloaded because both consumers read title and
    # description off every row — the ranking prompt and the offer's own list —
    # and title is translated, so ten candidates would otherwise be ten queries.
    Proposal
      .base_selection
      .where(projekt_phase_id: @projekt_phase.id)
      .includes(:translations)
      .pg_search_any_word(search_terms.join(" "))
      .limit(CANDIDATE_LIMIT)
      .to_a
  end

  private

    def search_terms
      @search_terms ||= @text.scan(/[[:alnum:]]+/).map(&:downcase).uniq.first(MAX_TERMS)
    end
end
