class Whatsapp::ProjektsByTopicQuery < ApplicationQuery
  # What a citizen says they want to talk about — "Verkehr", "etwas zum
  # Stadtpark" — which is not a projekt name and must not be resolved like one.
  # Whatsapp::ProjektByNameQuery answers "which projekt is this", one or none,
  # and refuses ambiguity on purpose, because subscribing someone to the wrong
  # projekt is a silent wrong answer. A topic is the opposite question: two
  # projekts about traffic is the answer, not a tie to be broken, and returning
  # nothing there sends the citizen back through the overview they were meant to
  # be spared.
  #
  # Matched on the title and the page subtitle. The subtitle is the portal's own
  # one-line summary of what a projekt is for, which is what a topic asks after;
  # the page text under it is deliberately left out, where a projekt that
  # mentions the word once in a paragraph would rank beside one that is about it.
  MIN_TERM_LENGTH = 3

  # The trigram floor from the name query, and for the same reason: below it a
  # projekt sharing one word with another matches it. Applied to the title only —
  # a short term scored against a whole subtitle falls under any usable floor, so
  # the subtitle is matched by containment and never by similarity.
  MINIMUM_SCORE = ::Whatsapp::ProjektByNameQuery::MINIMUM_SCORE

  MAX_RESULTS = ::Whatsapp::MAX_LIST_ROWS

  # Named rather than numbered at the sort, because the order is the answer's
  # shape: a projekt whose title is the topic comes before one that merely
  # describes it, and a fuzzy hit comes last of all.
  TITLE_MATCH = 0
  SUBTITLE_MATCH = 1
  CLOSE_TITLE = 2

  # The same set a named projekt resolves against, deliberately wider than the
  # overview: a citizen asking about a topic is often asking what came of it, and
  # a finished projekt reported as matching nothing reads as the portal having
  # lost it.
  def initialize(term:, candidates: nil)
    @term = term.to_s.strip
    @candidates = candidates
    @title_scores = {}
  end

  def call
    return [] if unusable_term?

    ranked
      .sort_by { |projekt, rank, score| [rank, -score, projekt.id] }
      .map(&:first)
      .first(MAX_RESULTS)
  end

  private

    # The normalised form is checked as well as the raw length: "..." is three
    # characters and normalises to nothing, and an empty term is a substring of
    # every title.
    def unusable_term?
      @term.length < MIN_TERM_LENGTH || normalized_term.blank?
    end

    def ranked
      loaded_candidates.filter_map do |projekt|
        rank = rank_of(projekt)

        next if rank.nil?

        [projekt, rank, title_score(projekt)]
      end
    end

    def rank_of(projekt)
      return TITLE_MATCH if normalized(title_of(projekt)).include?(normalized_term)
      return SUBTITLE_MATCH if normalized(subtitle_of(projekt)).include?(normalized_term)
      return CLOSE_TITLE if title_score(projekt) >= MINIMUM_SCORE

      nil
    end

    # Memoised per projekt because the rank asks for it and the sort asks again,
    # and a trigram score over the whole candidate set is the work here.
    def title_score(projekt)
      @title_scores[projekt.id] ||= TextSimilarity.trigram_score(@term, title_of(projekt))
    end

    def normalized_term
      @normalized_term ||= TextSimilarity.normalize(@term)
    end

    def normalized(text)
      TextSimilarity.normalize(text).to_s
    end

    def loaded_candidates
      @loaded_candidates ||=
        (@candidates || ::Whatsapp::ProjektByNameQuery.readable_candidates).to_a
    end

    def title_of(projekt)
      ::Whatsapp::ProjektLink.title(projekt).to_s
    end

    def subtitle_of(projekt)
      ::Whatsapp::ProjektCard.subtitle(projekt).to_s
    end
end
