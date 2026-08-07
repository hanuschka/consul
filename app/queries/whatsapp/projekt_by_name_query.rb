class Whatsapp::ProjektByNameQuery < ApplicationQuery
  # Resolves the projekt a citizen names in "Subscribe <name>". Deliberately
  # narrow: an exact case-insensitive hit wins, and a partial one only counts
  # when it is the single match. Subscribing someone to the wrong projekt is a
  # silent wrong answer, so ambiguity returns nothing and lets the caller ask.
  MIN_TERM_LENGTH = 3

  def initialize(term:)
    @term = term.to_s.strip
  end

  def call
    return if @term.length < MIN_TERM_LENGTH

    exact_match || sole_partial_match
  end

  private

    def scope
      Projekt.index_order_underway.includes(:page)
    end

    def exact_match
      candidates.find { |projekt| title_of(projekt).casecmp?(@term) }
    end

    def sole_partial_match
      matches = candidates.select { |projekt| title_of(projekt).downcase.include?(@term.downcase) }

      return if matches.size != 1

      matches.first
    end

    def candidates
      @candidates ||= scope.to_a
    end

    def title_of(projekt)
      Whatsapp::ProjektLink.title(projekt).to_s
    end
end
