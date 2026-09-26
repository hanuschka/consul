class SimilarContributions::Ranking < ApplicationService
  MINIMUM_RELEVANCE = 60
  REQUEST_TIMEOUT = 20
  CACHE_TTL = 10.minutes

  SYSTEM_PROMPT = <<~TEXT.freeze
    You are an assistant for a citizen participation platform. Municipal staff
    and citizens rely on you to recognise when a new contribution duplicates a
    concern that has already been raised.

    You compare one new citizen contribution against a list of existing
    contributions. Return only entries that address substantially the same
    concern, not merely the same general topic. Judge meaning, not wording:
    different phrasing, spelling variants and levels of detail still describe
    the same concern, while a shared subject area with a different request does
    not. Two contributions about the same subject at clearly different
    locations are not the same concern.

    Score each returned entry from 0 to 100, where 100 means the two
    contributions ask for the same thing and 60 means a reader would still see
    them as the same concern. Return an empty list when nothing is comparable.
    Give a short reason for every entry you return, naming what the two
    contributions have in common. Write every reason in %{target_language}.
  TEXT

  Match = Struct.new(:resource, :relevance, :reason, keyword_init: true)

  def initialize(candidates, title:, description:, limit:, feature:, projekt_phase: nil)
    @candidates = candidates
    @title = title
    @description = description
    @limit = limit
    @feature = feature
    @projekt_phase = projekt_phase
  end

  # A provider error is not an empty answer: it goes on to the caller, which is
  # a job that records it and retries.
  def call
    return [] if candidates.empty?

    build_matches(cached_ranking)
  end

  private

    attr_reader :candidates, :title, :description, :limit, :feature, :projekt_phase

    # A rejected submission re-renders the same form against the same
    # candidates, so without this every retry pays for another ranking and
    # shows the citizen a differently ordered list.
    def cached_ranking
      Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
        request_ranking
      end
    end

    def cache_key
      request_digest = Digest::SHA256.hexdigest("#{system_instructions}\n#{user_prompt}")

      "similar_contributions_ranking/#{request_digest}"
    end

    # Ranking picks from a list Postgres already narrowed down, so the cheapest
    # tier is enough — see Ai::ModelProfile.ultrafast.
    def request_ranking
      response =
        Ai::RubyLlmFactory
          .chat_for(
            Ai::ModelProfile.ultrafast,
            feature: feature,
            request_timeout: REQUEST_TIMEOUT
          )
          .with_schema(output_schema)
          .with_instructions(system_instructions)
          .ask(user_prompt)

      Array(response.content["matches"])
    end

    def build_matches(ranked_entries)
      candidates_by_id = candidates.index_by(&:id)

      ranked_entries
        .select { |entry| entry["relevance"].to_i >= MINIMUM_RELEVANCE }
        .sort_by { |entry| -entry["relevance"].to_i }
        .filter_map do |entry|
          resource = candidates_by_id[entry["id"].to_i]
          next if resource.nil?

          Match.new(resource: resource, relevance: entry["relevance"].to_i, reason: entry["reason"])
        end
        .first(limit)
    end

    def system_instructions
      @system_instructions ||=
        begin
          instructions =
            sprintf(SYSTEM_PROMPT, target_language: AiAnalytics::ClusteringCore.target_language)

          Ai::EvaluationContext.prepend_to(instructions, projekt_phase)
        end
    end

    def user_prompt
      @user_prompt ||= <<~TEXT
        New contribution:
        Title: #{title}
        Description: #{SimilarContributions::SearchTerms.strip_html(description).truncate(1500)}

        Existing contributions:
        #{candidates_text}
      TEXT
    end

    def candidates_text
      candidates.map do |candidate|
        stripped_description = SimilarContributions::SearchTerms.strip_html(candidate.description)

        "[id=#{candidate.id}] #{candidate.title}\n#{stripped_description.truncate(400)}"
      end.join("\n\n")
    end

    def output_schema
      {
        type: "object",
        properties: {
          matches: {
            type: "array",
            items: {
              type: "object",
              properties: {
                id: { type: "integer" },
                relevance: { type: "integer" },
                reason: { type: "string" }
              },
              required: ["id", "relevance", "reason"],
              additionalProperties: false
            }
          }
        },
        required: ["matches"],
        additionalProperties: false
      }
    end
end
