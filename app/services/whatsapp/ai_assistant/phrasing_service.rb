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

  # How long a miss stands before another one is scheduled. It doubles as the
  # negative cache: a provider that is down leaves the empty set in place for
  # this long instead of being asked again by every message.
  PENDING_TTL = 5.minutes

  def initialize(key:)
    @key = key.to_s
  end

  # Always returns something sendable, and never waits on a completion to do
  # it. A miss schedules the generation and answers from the locale file this
  # time; the variety appears on the next message rather than costing this
  # citizen the round trip.
  #
  # Every other failure — AI switched off, the key not on the list, an
  # unreachable provider, a reply that came back empty — lands on the same
  # fallback, which is the sentence the variants were generated from.
  def call
    return fixed_text if !phrasable?

    variants.sample.presence || fixed_text
  rescue StandardError => e
    Rails.logger.error("[Whatsapp] phrasing failed for #{@key}: #{e.class} - #{e.message}")

    fixed_text
  end

  # The cache key is the whole identity of a phrase set: one entry per locale
  # and address form, holding every key at once. Exposed so the job that fills
  # it writes to exactly the entry the request looked in.
  def self.cache_key(locale:, address_form:)
    ["whatsapp/phrasing", locale, address_form].join("/")
  end

  # Called from the job, off the inbound path. Returns the set it stored.
  #
  # The address form is read fresh rather than taken from the caller: it is
  # what the prompt is built from, so writing this generation under the form
  # that was current when the job was enqueued would file a "du" set under
  # "sie". An admin who flips the setting mid-flight leaves the old entry to
  # expire on its own and the next miss schedules the new one.
  def self.refresh(locale:)
    I18n.with_locale(locale) do
      phrases = new(key: PHRASED_KEYS.first).generate_phrases
      key = cache_key(locale: locale, address_form: ::Whatsapp.address_form)

      Rails.cache.write(key, phrases, expires_in: phrases.present? ? CACHE_TTL : PENDING_TTL)

      phrases
    end
  end

  # Every key in one completion. Asked one at a time the model writes the same
  # sentence twice anyway, so the batch is both cheaper and more varied.
  # Public only so `refresh` can reach it; there is no other caller.
  def generate_phrases
    return {} if !::Ai::Settings.ai_available?

    response_content["phrases"].to_a.each_with_object({}) do |phrase, phrases|
      key = phrase["key"].to_s

      next if !PHRASED_KEYS.include?(key)

      variants = phrase["variants"].to_a.map { |variant| variant.to_s.strip }.select(&:present?)

      phrases[key] = variants if variants.present?
    end
  end

  private

    def fixed_text
      I18n.t(@key)
    end

    # Deliberately without the availability check: that one reads a credential
    # out of the database, and the request path never generates anything, so
    # the question belongs in the job. Both checks here are free.
    def phrasable?
      PHRASED_KEYS.include?(@key) && cacheable?
    end

    # Without a cache this is a completion on every message the bot sends,
    # including the ones that are instant today. Development runs on the null
    # store unless caching is switched on, and paying for variety nobody asked
    # for is the wrong default there — the fixed sentence is.
    def cacheable?
      !Rails.cache.is_a?(ActiveSupport::Cache::NullStore)
    end

    # One entry for the whole set rather than one per line. A message that
    # produces a draft says three of these — the "one moment", the sentence
    # above the card and the question under it — and one entry means one
    # generation covers all three rather than three of them expiring at three
    # different times.
    #
    # The address form is part of the key rather than a reason to expire it: a
    # portal that switches from Sie to du would otherwise keep answering in the
    # old one until the TTL ran out.
    def cache_key
      self.class.cache_key(locale: I18n.locale, address_form: ::Whatsapp.address_form)
    end

    def variants
      phrase_set[@key].to_a
    end

    # `nil` means nothing is stored, which schedules a refresh and answers from
    # the locale file meanwhile. An empty hash means a refresh is already
    # scheduled, or its generation failed; it stands for PENDING_TTL so the
    # next message neither waits nor enqueues the same job again.
    def phrase_set
      cached = Rails.cache.read(cache_key)

      return cached if !cached.nil?

      schedule_refresh

      {}
    end

    # The empty set is written here rather than by the job, and before the job
    # is enqueued: that write is the whole reason a burst of messages produces
    # one generation instead of one each.
    def schedule_refresh
      Rails.cache.write(cache_key, {}, expires_in: PENDING_TTL)

      Whatsapp::RefreshPhrasingJob.perform_later(I18n.locale.to_s)
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
        You rewrite the short fixed lines a chatbot says to a citizen on WhatsApp. For every line
        you are given, return #{VARIANT_COUNT} alternatives that mean exactly the same thing as
        the original and could replace it without anything else in the conversation changing.

        Rules:
        - Write in #{output_language}, addressing the citizen #{address_form_instruction}.
        - Keep each one to the length of its original, one or two short sentences at most.
        - Keep whatever the original does: a question stays a question, a line ending in a colon
          still introduces what follows it.
        - No emoji, no markdown, no placeholders, no greeting or sign-off, no invented detail.
        - Vary the wording, not the meaning or the register. Every line, and every alternative of
          it, must read as the same bot.
        - Return one entry per line you were given, echoing its key back unchanged.
      TEXT
    end

    def user_prompt
      lines = PHRASED_KEYS.map { |key| "#{key}\n\"#{I18n.t(key)}\"" }

      <<~PROMPT
        The lines, each as its key followed by the original:

        #{lines.join("\n\n")}
      PROMPT
    end

    def output_schema
      {
        type: "object",
        properties: {
          phrases: {
            type: "array",
            items: {
              type: "object",
              properties: {
                key: {
                  type: "string",
                  enum: PHRASED_KEYS,
                  description: "The key of the line these rewordings replace."
                },
                variants: {
                  type: "array",
                  items: { type: "string" },
                  description: "#{VARIANT_COUNT} interchangeable rewordings of that line."
                }
              },
              required: %w[key variants],
              additionalProperties: false
            },
            description: "One entry for each line given, in any order."
          }
        },
        required: %w[phrases],
        additionalProperties: false
      }
    end

    def address_form_instruction
      ::Whatsapp.address_form_instruction
    end

    def output_language
      ::Ai::OutputLanguage.chat_name_for(I18n.locale)
    end
end
