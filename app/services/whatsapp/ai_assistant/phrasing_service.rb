class Whatsapp::AiAssistant::PhrasingService < ApplicationService
  # The bot's routine prose, said differently each time. A citizen who submits
  # three ideas in a week used to read the same four sentences nine times, and
  # a chat that repeats itself word for word reads as a form rather than an
  # answer.
  #
  # Only prose goes through here. Buttons, list rows and anything carrying an
  # interpolation stay fixed: a row title is matched against a tapped id, and a
  # sentence the model rewrites is a sentence it can rewrite without the
  # %{title} in it.
  #
  # It is also where the portal's du/Sie setting reaches the fixed copy. The
  # locale files are written formally, so on a portal set to "du" every
  # sentence in PHRASED_KEYS is the informal one and the rest are not — which
  # is the trade the setting makes, and the reason the list is worth extending
  # rather than the copy worth duplicating per address form.
  PHRASED_KEYS = %w[
    whatsapp.bot.drafting
    whatsapp.bot.proposal.ask_idea
    whatsapp.bot.proposal.ask_revision
    whatsapp.bot.proposal.ask_image
    whatsapp.bot.proposal.draft_intro
    whatsapp.bot.proposal.draft_question
    whatsapp.bot.proposal.draft_revised_intro
    whatsapp.bot.proposal.draft_revised_question
    whatsapp.bot.proposal.preview_intro
    whatsapp.bot.proposal.preview_question
    whatsapp.bot.proposal.cancelled
    whatsapp.bot.proposal.next_action
  ].freeze

  # Enough that a run of messages does not repeat, few enough that one call
  # produces them all. They are generated together on purpose: asked one at a
  # time the model writes the same sentence twice.
  VARIANT_COUNT = 5

  # Long, because the alternative is paying for a completion on a message that
  # is otherwise instant. A portal that changes its address form waits this out
  # or restarts, which is the same deal every Setting-backed cache here makes.
  CACHE_TTL = 12.hours

  def initialize(key:)
    @key = key.to_s
  end

  # Always returns something sendable. Every failure — AI switched off, the key
  # not on the list, an unreachable provider, a reply that came back empty —
  # falls back to the sentence in the locale file, which is the one this was
  # generated from.
  def call
    return fixed_text if !phrasable?

    variants.sample.presence || fixed_text
  rescue StandardError => e
    Rails.logger.error("[Whatsapp] phrasing failed for #{@key}: #{e.class} - #{e.message}")

    fixed_text
  end

  private

    def fixed_text
      I18n.t(@key)
    end

    def phrasable?
      PHRASED_KEYS.include?(@key) && ::Ai::Settings.ai_available? && cacheable?
    end

    # Without a cache this is a completion on every message the bot sends,
    # including the ones that are instant today. Development runs on the null
    # store unless caching is switched on, and paying for variety nobody asked
    # for is the wrong default there — the fixed sentence is.
    def cacheable?
      !Rails.cache.is_a?(ActiveSupport::Cache::NullStore)
    end

    # The address form is part of the cache key rather than a reason to expire
    # it: a portal that switches from Sie to du would otherwise keep answering
    # in the old one until the TTL ran out.
    def cache_key
      ["whatsapp/phrasing", @key, I18n.locale, ::Whatsapp.address_form].join("/")
    end

    def variants
      cached = Rails.cache.read(cache_key)

      return cached if cached.present?

      generated = generate

      return [fixed_text] if generated.blank?

      Rails.cache.write(cache_key, generated, expires_in: CACHE_TTL)

      generated
    end

    def generate
      content = response_content

      content["variants"].to_a.map { |variant| variant.to_s.strip }.select(&:present?)
    end

    def response_content
      ::Ai::RubyLlmFactory
        .chat_with_json_output(output_schema)
        .with_instructions(instructions)
        .ask(user_prompt)
        .content
        .to_h
    end

    def instructions
      <<~TEXT
        You rewrite one short line a chatbot says to a citizen on WhatsApp. Give
        #{VARIANT_COUNT} alternatives that mean exactly the same thing as the original and could
        replace it without anything else in the conversation changing.

        Rules:
        - Write in #{output_language}, addressing the citizen #{address_form_instruction}.
        - Keep each one to the length of the original, one or two short sentences at most.
        - Keep whatever the original does: a question stays a question, a line ending in a colon
          still introduces what follows it.
        - No emoji, no markdown, no placeholders, no greeting or sign-off, no invented detail.
        - Vary the wording, not the meaning or the register. They must read as the same bot.
      TEXT
    end

    def user_prompt
      <<~PROMPT
        The original line:
        "#{fixed_text}"
      PROMPT
    end

    def output_schema
      {
        type: "object",
        properties: {
          variants: {
            type: "array",
            items: { type: "string" },
            description: "#{VARIANT_COUNT} interchangeable rewordings of the original line."
          }
        },
        required: %w[variants],
        additionalProperties: false
      }
    end

    def address_form_instruction
      ::Whatsapp.address_form_instruction
    end

    def output_language
      ::Ai::OutputLanguage::LANGUAGE_NAMES.fetch(I18n.locale.to_s, ::Ai::OutputLanguage::FALLBACK)
    end
end
