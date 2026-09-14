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
  # Matched on four things, in falling order of how directly each says the projekt
  # is about the subject: the title, the names of its phases, the page subtitle,
  # and the words of the term.
  #
  # The phase names are the layer this was missing, and it was the one a citizen
  # is most likely to use: the bot prints them on the card — a voting phase is
  # named by its ballot rather than by itself (Whatsapp::ProjektCard.phase_facts)
  # — so "Parken in der Ortsmitte" is a name the citizen read here and was then
  # told the portal holds nothing on.
  #
  # The page text under the subtitle is still deliberately left out, where a
  # projekt that mentions the word once in a paragraph would rank beside one that
  # is about it.
  MIN_TERM_LENGTH = 3

  # The trigram floor from the name query, and for the same reason: below it a
  # projekt sharing one word with another matches it. Applied to the title only —
  # a short term scored against a whole subtitle falls under any usable floor, so
  # the subtitle is matched by containment and never by similarity.
  MINIMUM_SCORE = ::Whatsapp::ProjektByNameQuery::MINIMUM_SCORE

  MAX_RESULTS = ::Whatsapp::MAX_OFFERED_LIST_ROWS

  # Named rather than numbered at the sort, because the order is the answer's
  # shape: a projekt whose title is the topic comes before one that merely
  # describes it, and a fuzzy hit comes last of all.
  TITLE_MATCH = 0
  PHASE_MATCH = 1
  SUBTITLE_MATCH = 2
  CLOSE_TITLE = 3
  WORD_MATCH = 4

  # How long a portal-wide map of phase names is kept once its version key still
  # answers. Hygiene rather than correctness — the key carries the count and the
  # newest timestamp of both tables, so a renamed phase invalidates it the moment it
  # is saved.
  PHASE_NAMES_TTL = 1.day

  # The projekt, and the phase whose name is why it matched. The phase is the
  # difference between an answer the citizen has to work through a card to use and
  # one they can act on: a topic that named a ballot has already said which phase
  # it means, and handing back the projekt alone asks them that again.
  #
  # The id rather than the record, because the names are read from a cache and a
  # cached ActiveRecord object is a stale one. What the caller does with it —
  # start_draft, start_poll_vote — takes the id anyway.
  Match = Struct.new(:projekt, :projekt_phase_id, :phase_name, keyword_init: true)

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
      .sort_by { |match, rank, score| [rank, -score, match.projekt.id] }
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

        [match_of(projekt, rank), rank, title_score(projekt)]
      end
    end

    # The phase travels only where it is what matched. A projekt found by its own
    # title may have five phases and none of them is the one the citizen meant, and
    # naming one of them anyway is the guess this query exists not to make.
    def match_of(projekt, rank)
      projekt_phase_id, name = named_phase(projekt) if rank == PHASE_MATCH

      Match.new(projekt: projekt, projekt_phase_id: projekt_phase_id, phase_name: name)
    end

    def rank_of(projekt)
      return TITLE_MATCH if normalized(title_of(projekt)).include?(normalized_term)
      return PHASE_MATCH if named_phase(projekt).present?
      return SUBTITLE_MATCH if normalized(subtitle_of(projekt)).include?(normalized_term)
      return CLOSE_TITLE if title_score(projekt) >= MINIMUM_SCORE
      return WORD_MATCH if every_word_matches?(projekt)

      nil
    end

    # Containment both ways, because a phase name and a topic meet each other from
    # either side: "Parken in der Ortsmitte" is the whole of a ballot's name, and
    # "Parken" is a part of it.
    def named_phase(projekt)
      @named_phases ||= {}

      return @named_phases[projekt.id] if @named_phases.key?(projekt.id)

      @named_phases[projekt.id] = phases_of(projekt).find do |_projekt_phase_id, name|
        normalized(name).include?(normalized_term) || normalized_term.include?(normalized(name))
      end
    end

    # The last layer, and the one that reaches a compound. Every significant word of
    # the term has to land somewhere in the projekt's own words — title, phase names
    # and subtitle together — so "Parken" reaches "Parkraumkonzept" while "Parken in
    # der Ortsmitte" does not reach it on the strength of "Parken" alone.
    def every_word_matches?(projekt)
      return false if significant_term_words.empty?

      candidate_words = words_of(projekt)

      significant_term_words.all? do |term_word|
        candidate_words.any? { |candidate| TextSimilarity.same_stem?(term_word, candidate) }
      end
    end

    # Short words are dropped rather than compared whole: a topic is carried by its
    # nouns, and "in", "der" and "zum" are in every title on the portal.
    def significant_term_words
      @significant_term_words ||= TextSimilarity
        .words(@term)
        .select { |word| word.length >= TextSimilarity::STEM_PREFIX_LENGTH }
    end

    def words_of(projekt)
      @words_of ||= {}
      @words_of[projekt.id] ||= TextSimilarity.words(
        [title_of(projekt), phases_of(projekt).map(&:last), subtitle_of(projekt)].join(" ")
      )
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

    # {projekt_id => [[projekt_phase_id, name], ...]} for the whole portal, cached.
    #
    # Built portal-wide rather than for this search's candidates, because that is what
    # makes it cacheable: a phase belongs to its projekt whichever set a caller hands
    # in, and a map keyed on the candidate ids would be a fresh entry per search.
    #
    # Cached because every topic search that does not match on a title alone asks for
    # it, and building it materialises every visible phase on the portal with its
    # translations. The key carries both tables' count and newest timestamp, so a
    # renamed phase, a renamed ballot, a new phase and a deleted one each invalidate
    # it as they are saved — two cheap aggregate queries in place of thousands of
    # rows.
    #
    # Locale is part of the key: the names are Globalize translations, and a German
    # map answered to an English chat would match on words the citizen never saw.
    def phase_names_by_projekt
      @phase_names_by_projekt ||= Rails.cache.fetch(
        phase_names_cache_key, expires_in: PHASE_NAMES_TTL
      ) { build_phase_names }
    end

    def phase_names_cache_key
      [
        "whatsapp/projekt_phase_names",
        I18n.locale,
        visible_phases.cache_key_with_version,
        ::Poll.published.cache_key_with_version
      ]
    end

    def visible_phases
      ::ProjektPhase.where(hidden_at: nil, active: true)
    end

    # Named through Whatsapp::ProjektCard.phase_facts so the name matched here is the
    # name the citizen was shown — for a voting phase that is its published ballot's,
    # never the four phases all titled "Abstimmung".
    def build_phase_names
      projekt_phases = visible_phases.includes(:translations).to_a
      facts = ::Whatsapp::ProjektCard.phase_facts(projekt_phases)

      projekt_phases
        .group_by(&:projekt_id)
        .transform_values do |phases|
          phases
            .filter_map do |projekt_phase|
              name = facts[projekt_phase.id].name.to_s

              next if type_label?(projekt_phase, name)

              [projekt_phase.id, name]
            end
        end
    end

    # A phase called after its own type — "Kommentare", "Vorschläge", "Abstimmung" —
    # names no subject, and every projekt on the portal has one. Matched, a citizen
    # writing "Kommentar" is handed the whole portal back as though each of those
    # projekts were about commenting, which is the refusal this layer was added to
    # fix turned into noise of the same size.
    #
    # ProjektPhase#title falls back to exactly this label where no tab name is set,
    # and admins type it in by hand just as often, so the comparison is on the words
    # rather than on the column being empty.
    def type_label?(projekt_phase, name)
      normalized(name) == normalized(type_label_of(projekt_phase.class))
    end

    def type_label_of(phase_class)
      @type_labels ||= {}
      @type_labels[phase_class] ||= phase_class.model_name.human
    end

    def phases_of(projekt)
      phase_names_by_projekt.fetch(projekt.id, [])
    end

    def title_of(projekt)
      ::Whatsapp::ProjektLink.title(projekt).to_s
    end

    def subtitle_of(projekt)
      ::Whatsapp::ProjektCard.subtitle(projekt).to_s
    end
end
