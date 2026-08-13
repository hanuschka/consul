class Whatsapp::ProjektByNameQuery < ApplicationQuery
  # Resolves the projekt a citizen names in "Subscribe <name>". Deliberately
  # narrow: an exact case-insensitive hit wins, and a partial one only counts
  # when it is the single match. Subscribing someone to the wrong projekt is a
  # silent wrong answer, so ambiguity returns nothing and lets the caller ask.
  MIN_TERM_LENGTH = 3

  # Following a projekt only makes sense while it is running, so a name is
  # resolved against the underway set by default. Reading about one is the
  # opposite case: a citizen asking what came of a projekt is asking about a
  # finished one, which index_order_underway excludes by construction. Hence the
  # wider set here rather than a second query object with the same matching rules
  # in it.
  def self.readable(term:)
    new(term: term, candidates: Projekt.index_order_all.includes(:page)).call
  end

  # `candidates` takes anything enumerable of projekts, so a caller that has
  # already loaded them — the phase listing, which needs them for its rows — hands
  # them straight in rather than paying for a second query that could also match a
  # projekt whose phase is not open.
  def initialize(term:, candidates: nil)
    @term = term.to_s.strip
    @candidates = candidates
  end

  def call
    return if @term.length < MIN_TERM_LENGTH

    exact_match || sole_partial_match
  end

  private

    def exact_match
      loaded_candidates.find { |projekt| title_of(projekt).casecmp?(@term) }
    end

    def sole_partial_match
      matches = loaded_candidates.select do |projekt|
        title_of(projekt).downcase.include?(@term.downcase)
      end

      return if matches.size != 1

      matches.first
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
