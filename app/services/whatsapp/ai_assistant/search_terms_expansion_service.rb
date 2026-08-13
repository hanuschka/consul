class Whatsapp::AiAssistant::SearchTermsExpansionService < ApplicationService
  # The other words the portal might already hold the same request under. The
  # duplicate search matches the citizen's own tokens against proposal text, so
  # it finds a duplicate only when both people happened to reach for the same
  # noun: someone writing "Zebrastreifen" never met the proposal that asked for a
  # "Fußgängerüberweg", and the ranking call behind the search never saw it to
  # judge.
  #
  # An embedding index would answer this better and is not available here — the
  # database has no pgvector — so the widening happens on the query side instead,
  # which needs no column, no backfill and nothing kept in step with the
  # proposals table.
  #
  # Terms only, never a rewritten query. What comes back is fed to the same
  # any-word search and then to the same ranking call, which is what decides
  # whether a candidate is really the citizen's idea again. A loose synonym
  # therefore costs a candidate slot, not a wrong offer.
  REQUEST_TIMEOUT_SECONDS = 10

  # The search is one OR branch per term and the phase's whole proposal set is
  # behind it, so the widening is deliberately narrow: the words a duplicate
  # would plausibly be filed under, not everything adjacent to the topic.
  MAX_TERMS = 8

  # Below this there is nothing to find synonyms for — a two-word message is
  # usually a greeting or an answer to something else, and the search runs on it
  # unchanged as it always did.
  MIN_SOURCE_WORDS = 4

  def initialize(text:)
    @text = text.to_s.strip
  end

  # An empty list on every failure, which leaves the search exactly as it was
  # before this existed.
  def call
    return [] if @text.split.size < MIN_SOURCE_WORDS
    return [] if !::Ai::Settings.ai_available?

    expanded_terms
  rescue StandardError => e
    Rails.logger.error("[Whatsapp] search term expansion failed: #{e.class} - #{e.message}")

    []
  end

  private

    def expanded_terms
      terms = response_content["terms"]

      return [] if !terms.is_a?(Array)

      # Single words only, because that is what the any-word search matches on:
      # a returned phrase would be one branch that nothing contains. Split rather
      # than dropped, so a model answering "sicherer Übergang" still contributes
      # both halves.
      terms
        .flat_map { |term| term.to_s.scan(/[[:alnum:]]+/) }
        .map(&:downcase)
        .uniq
        .first(MAX_TERMS)
    end

    def response_content
      ::Ai::RubyLlmFactory
        .fast_chat(REQUEST_TIMEOUT_SECONDS)
        .with_schema(output_schema)
        .with_instructions(instructions)
        .ask(@text)
        .content
        .to_h
    end

    # Nouns, because that is what a proposal about the same thing is written
    # with and what the search index holds. Asking for "related words" produces
    # verbs and adjectives that match half the phase.
    def instructions
      <<~TEXT
        A citizen is describing something they want changed in their town, so it can be submitted
        to a participation portal. Someone else may have already asked for the same thing in
        different words. List the words their version would most likely use.

        Return single nouns, in the language the citizen wrote in, in their base form (nominative
        singular). Include:
        - other names for the same thing ("Zebrastreifen" and "Fußgängerüberweg", "Spielplatz" and
          "Spielgeräte", "Mülleimer" and "Abfallbehälter")
        - the everyday word where they used an official one, and the official word where they used
          an everyday one
        - the object itself where they described only its problem ("es ist zu dunkel" is about
          "Beleuchtung", "Straßenlaterne")

        Do not include:
        - words already in their message
        - street names, place names, district names or any other proper noun — those are what
          separates one request from another, and a similar-sounding street is not the same street
        - generic civic words that would match most of the portal: "Stadt", "Bürger", "Antrag",
          "Verbesserung", "Problem", "Maßnahme"

        At most #{MAX_TERMS} words. Fewer is better than padded, and an empty list is correct when
        the message is not about a thing at all.
      TEXT
    end

    def output_schema
      {
        type: "object",
        properties: {
          terms: {
            type: "array",
            description: "Single nouns a duplicate of this request would likely be written with.",
            items: { type: "string" }
          }
        },
        required: %w[terms],
        additionalProperties: false
      }
    end
end
