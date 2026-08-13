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

  # `extra_terms` are the words a duplicate might be written with instead of the
  # citizen's own — see AiAssistant::SearchTermsExpansionService, which is where
  # they come from. Passed in rather than fetched here: this is a query object,
  # and a completion hidden inside one is a cost its callers cannot see.
  def initialize(projekt_phase:, text:, extra_terms: [])
    @projekt_phase = projekt_phase
    @text = text.to_s.strip
    @extra_terms = extra_terms.to_a
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
    (matches_for(search_terms) | matches_for(unused_extra_terms)).first(CANDIDATE_LIMIT)
  end

  private

    # Two searches rather than one widened one, each with its own slots. Folded
    # into a single any-word query the citizen's own words win on term frequency
    # and fill the limit by themselves, which is the outcome the extra terms
    # exist to avoid: they are there for the proposal that shares the subject and
    # none of the vocabulary, and that proposal is last in a combined ranking or
    # not in it at all.
    def matches_for(terms)
      return [] if terms.blank?

      Proposal
        .base_selection
        .where(projekt_phase_id: @projekt_phase.id)
        .includes(:translations)
        .pg_search_any_word(terms.join(" "))
        .limit(CANDIDATE_LIMIT)
        .to_a
    end

    def search_terms
      @search_terms ||= tokenize(@text).first(MAX_TERMS)
    end

    # A term the citizen already used is not a second search, it is the first one
    # again — and dropping it here is what keeps the two result sets meaningfully
    # different rather than one being a subset of the other.
    def unused_extra_terms
      @unused_extra_terms ||= (tokenize(@extra_terms.join(" ")) - search_terms).first(MAX_TERMS)
    end

    def tokenize(text)
      text.to_s.scan(/[[:alnum:]]+/).map(&:downcase).uniq
    end
end
