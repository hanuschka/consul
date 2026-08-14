class Whatsapp::AiAssistant::DescriptionSummaryService < ApplicationService
  # A contribution's description cut to fit a chat message, in sentences rather
  # than mid-word. Every surface that quotes one used to call Whatsapp.plain_text,
  # which strips the markup and calls truncate — so a draft card ended "…die
  # Situation an der Kreuzung ist besonders für Kinder auf dem Weg zur Sc…" and a
  # list row, which WhatsApp allows 72 characters, rarely got past the first
  # clause.
  #
  # Only where a citizen reads it. The three services that hand a description to
  # another model keep truncating: a summary there would pay for a completion to
  # produce the input of the next one, and a model reading a clipped sentence
  # loses nothing.
  REQUEST_TIMEOUT_SECONDS = 15

  # What the model is shown. Past this the description is a document rather than
  # a contribution, and the opening is what a summary of it is built from anyway.
  SOURCE_LENGTH = 2500

  # Cached per record and per length, because the same description is summarised
  # for the card and again for a list row at a very different size. updated_at is
  # in the key rather than swept on save: an edited draft is a different record
  # to quote, and a key that carries the stamp cannot go stale.
  CACHE_EXPIRY = 30.days

  def initialize(resource:, length:)
    @resource = resource
    @length = length
  end

  # Always answers with something the caller can print. The truncation it
  # replaces is also its fallback, so an unreachable provider costs the citizen
  # the ragged edge they had before rather than an empty card.
  def call
    return truncated if source_text.blank?
    return truncated if source_text.length <= @length
    return truncated if !::Ai::Settings.ai_available?

    cached_summary || truncated
  end

  private

    def truncated
      ::Whatsapp.plain_text(@resource.description, length: @length)
    end

    def source_text
      @source_text ||= ::Whatsapp.plain_text(@resource.description, length: SOURCE_LENGTH)
    end

    # Written back only when the model actually produced something, so a failed
    # generation is retried on the next send rather than cached as a permanent
    # ragged edge.
    def cached_summary
      cached = Rails.cache.read(cache_key)

      return cached if cached.present?

      summary = generate

      return if summary.blank?

      Rails.cache.write(cache_key, summary, expires_in: CACHE_EXPIRY)

      summary
    end

    def cache_key
      [
        "whatsapp/description_summary",
        @resource.class.name,
        @resource.id,
        @resource.updated_at.to_i,
        @length
      ]
    end

    def generate
      summary = response_content["summary"].to_s.squish

      return if summary.blank?

      # The length is what the surface has room for, and a model asked for "about
      # 70 characters" will sometimes hand back 90. Cut rather than re-asked: the
      # sentence is already whole, and one that overshoots by a few words is
      # still better read than a hard cut through the original.
      summary.truncate(@length)
    rescue StandardError => e
      Rails.logger.error("[Whatsapp] description summary failed: #{e.class} - #{e.message}")

      nil
    end

    def response_content
      ::Ai::RubyLlmFactory
        .fast_chat(REQUEST_TIMEOUT_SECONDS)
        .with_schema(output_schema)
        .with_instructions(instructions)
        .ask(source_text)
        .content
        .to_h
    end

    # The citizen's own contribution, so the summary is a shortening and not a
    # rewrite: no praise, no framing, nothing added that they did not say. It is
    # shown back to them as what they wrote, and a sentence they do not recognise
    # is worse than a sentence that stops early.
    def instructions
      <<~TEXT
        You are shortening a citizen's contribution to a participation portal so it fits in a chat
        message. Write a summary of at most #{@length} characters.

        Rules:
        - Same language as the text you are given. Never translate.
        - Whole sentences that end properly. This replaces a hard cut mid-word, so stopping early
          is the one thing it must not do.
        - Keep what the contribution asks for and where, including street names, place names and
          numbers. Those are what makes it recognisable to the person who wrote it.
        - Say nothing that is not in the text. Do not judge it, introduce it, or add a conclusion.
        - No greeting, no "the citizen writes", no quotation marks around the whole thing.
      TEXT
    end

    def output_schema
      {
        type: "object",
        properties: {
          summary: {
            type: "string",
            description: "The shortened contribution, at most #{@length} characters, in the " \
                         "language of the original."
          }
        },
        required: %w[summary],
        additionalProperties: false
      }
    end
end
