class Whatsapp::ProjektByNameQuery < ApplicationQuery
  # Resolves the projekt a citizen names in "Subscribe <name>". Deliberately
  # narrow: an exact hit wins, a partial one only when it is the single match,
  # and a close one only when nothing else is nearly as close. Subscribing
  # someone to the wrong projekt is a silent wrong answer, so ambiguity returns
  # nothing and lets the caller ask.
  MIN_TERM_LENGTH = 3

  # Comparison is on TextSimilarity's normalised form throughout, so "Grunflache"
  # reaches "Grünflächen" and "st.-marien-platz" reaches "St. Marien Platz".
  # Before this, a citizen who left out an umlaut was told no such projekt
  # existed, which reads as the portal having lost it.
  #
  # The two numbers are what keeps a fuzzy match from being a guess. The floor is
  # above pg_trgm's own default because the strings are short — at 0.3 a projekt
  # sharing one word with another matches it — and the lead is what a candidate
  # must beat the runner-up by: "Innenstadt Nord" sits 0.55 from "Innenstadt Süd"
  # and 0.47 from "Innenstadtentwicklung Nord-Ost", which is exactly the case
  # that must be asked about rather than decided.
  MINIMUM_SCORE = 0.45
  MINIMUM_LEAD = 0.15

  # How many near-misses a caller may show the citizen when nothing resolved.
  # Three because the answer is offered as a question, and a list of everything
  # that shares a syllable is not a question.
  MAX_SUGGESTIONS = 3

  # Following a projekt only makes sense while it is running, so a name is
  # resolved against the underway set by default. Reading about one is the
  # opposite case: a citizen asking what came of a projekt is asking about a
  # finished one, which index_order_underway excludes by construction. Hence the
  # wider set here rather than a second query object with the same matching rules
  # in it.
  def self.readable(term:)
    new(term: term, candidates: Projekt.index_order_all.includes(:page)).call
  end

  # The titles that nearly matched, for a caller with nothing to report. The
  # assistant is told "no single projekt matches"; handing it these lets it ask
  # "did you mean X?" instead of listing the whole portal back at someone who
  # named their projekt almost correctly.
  def self.suggestions(term:, candidates: nil)
    new(term: term, candidates: candidates).near_titles
  end

  # `candidates` takes anything enumerable of projekts, so a caller that has
  # already loaded them — the phase listing, which needs them for its rows — hands
  # them straight in rather than paying for a second query that could also match a
  # projekt whose phase is not open.
  def initialize(term:, candidates: nil)
    @term = term.to_s.strip
    @candidates = candidates
  end

  # The normalised form is checked as well as the raw length: "..." is three
  # characters and normalises to nothing, and an empty term is a substring of
  # every title, which would resolve to whichever projekt happened to be alone.
  def call
    return if unusable_term?
    return exact_match if exact_match.present?

    # Several titles containing the term is the citizen having named a projekt
    # ambiguously, and that is an answer — not a case for the fuzzy pass to break
    # the tie in. "Munich" sits inside both "Munich center" and "Munich budget
    # stats", and scoring alone prefers the shorter title, which would subscribe
    # someone to a projekt they never named.
    return if partial_matches.many?
    return partial_matches.first if partial_matches.one?

    sole_close_match
  end

  # Everything that contains the term, plus everything scoring near it, in score
  # order. The two sets have to be joined rather than scored alone: a title that
  # contains the term outright is the clearest near-miss there is, and a long one
  # ("Munich budget stats" for "Munich") still falls under the floor because most
  # of its trigrams are words the citizen never typed.
  def near_titles
    return [] if unusable_term?

    close_projekts = scored_candidates
      .select { |_projekt, score| score >= MINIMUM_SCORE }
      .map { |projekt, _score| projekt }

    ordered_by_score(partial_matches | close_projekts)
      .first(MAX_SUGGESTIONS)
      .map { |projekt| title_of(projekt) }
  end

  private

    def unusable_term?
      @term.length < MIN_TERM_LENGTH || normalized_term.blank?
    end

    def exact_match
      return @exact_match if defined?(@exact_match)

      @exact_match =
        loaded_candidates.find { |projekt| normalized_title(projekt) == normalized_term }
    end

    def partial_matches
      @partial_matches ||= loaded_candidates.select do |projekt|
        normalized_title(projekt).include?(normalized_term)
      end
    end

    # Only when one candidate is both close enough and clearly closer than
    # whatever came second. A field of one skips the comparison: there is no
    # runner-up to be confused with, so the floor is the whole test.
    def sole_close_match
      best_projekt, best_score = scored_candidates.first

      return if best_score.blank? || best_score < MINIMUM_SCORE

      runner_up_score = scored_candidates.dig(1, 1)

      return best_projekt if runner_up_score.blank?
      return if best_score - runner_up_score < MINIMUM_LEAD

      best_projekt
    end

    def ordered_by_score(projekts)
      projekts.sort_by { |projekt| -TextSimilarity.trigram_score(@term, title_of(projekt)) }
    end

    # Sorted once and read by both the match and the suggestions, so the two can
    # never disagree about which projekt was closest.
    def scored_candidates
      @scored_candidates ||=
        loaded_candidates
          .map { |projekt| [projekt, TextSimilarity.trigram_score(@term, title_of(projekt))] }
          .sort_by { |_projekt, score| -score }
    end

    def normalized_term
      @normalized_term ||= TextSimilarity.normalize(@term)
    end

    def normalized_title(projekt)
      TextSimilarity.normalize(title_of(projekt))
    end

    # Materialised once. The default carries its own preload because every match
    # is decided on Whatsapp::ProjektLink.title, which reads the page.
    def loaded_candidates
      @loaded_candidates ||= (@candidates || Projekt.index_order_underway.includes(:page)).to_a
    end

    def title_of(projekt)
      Whatsapp::ProjektLink.title(projekt).to_s
    end
end
