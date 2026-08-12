class Whatsapp::AiAssistant::GeneratePhrasesService < ApplicationService
  # One completion's worth of rewordings, for the slice of keys it is given.
  # Split out of PhrasingService because the read path and the generation have
  # nothing in common but the map: this one owns the prompt, the schema and the
  # check that what came back is actually sendable.
  #
  # `keys` is a slice of PhrasingService::PHRASED_KEYS.
  #
  # Wider than `%{name}` because i18n accepts two more forms the bot's copy does
  # not use yet: the pluralised `%{count|other}` and the positional `%<name>d`.
  # Both would have read as no placeholder at all, so a variant that dropped one
  # would pass the check that exists to catch exactly that. Deliberately not
  # I18n::INTERPOLATION_PATTERN, whose several capture groups would change what
  # a scan of it returns.
  PLACEHOLDER_PATTERN = /%[{<]([\w|]+)[}>]/

  def initialize(keys:, variant_count:)
    @keys = keys
    @variant_count = variant_count
    @original_lines = {}
  end

  def call
    response_content["phrases"].to_a.each_with_object({}) do |phrase, phrases|
      key = phrase["key"].to_s

      next if !@keys.include?(key)

      variants = usable_variants(key, phrase["variants"])

      phrases[key] = variants if variants.present?
    end
  end

  private

    # A variant that lost a `%{title}` raises when it is sent, and one that
    # gained a line break turns a two-line notification into a paragraph with a
    # URL in the middle of it. Both are cheaper to drop here than to discover in
    # a chat: a key with no usable variant falls back to its locale sentence.
    def usable_variants(key, variants)
      Array(variants).map { |variant| variant.to_s.strip }.select do |variant|
        variant.present? && matches_original?(key, variant)
      end
    end

    def matches_original?(key, variant)
      original = original_line(key)

      placeholders(variant) == placeholders(original) &&
        variant.lines.size == original.lines.size
    end

    def placeholders(text)
      text.scan(PLACEHOLDER_PATTERN).flatten.uniq.sort
    end

    # The source sentence with its placeholders still in it: a lookup with no
    # arguments does not interpolate at all, so this is the one place the
    # placeholders a line carries are read, and they are read off the copy rather
    # than off a list of names kept beside it.
    def original_line(key)
      @original_lines[key] ||= I18n.t(key)
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
        you are given, return #{@variant_count} alternatives that mean exactly the same thing as
        the original and could replace it without anything else in the conversation changing.

        Rules:
        - Write in #{output_language}, addressing the citizen #{address_form_instruction}. This
          governs every pronoun and every possessive, not only the ones the original happens to
          use: rewrite the whole line into that address form even where the original is in the
          other one. In German that means "du/dich/dir/dein/deine" throughout for the informal
          form and "Sie/Ihnen/Ihr/Ihre" throughout for the formal one, and the verb agreeing with
          it. A single sentence in the wrong form makes the whole conversation read as broken,
          which is what these rewrites exist to prevent.
        - Keep each one to the length of its original, one or two short sentences at most.
        - Keep whatever the original does: a question stays a question, a line ending in a colon
          still introduces what follows it.
        - Reproduce every %{name} placeholder exactly as it appears, unchanged and unrenamed. Never
          add one the original does not have, never drop one it does, and never guess what it will
          hold.
        - Keep the line breaks of the original: an alternative has exactly as many lines as the line
          it replaces, and a placeholder that sits alone on its own line stays alone on its own
          line.
        - Keep any emoji the original has, in the same position, and add none that it does not.
        - Never drop a statement of fact. A line that says the sender is an AI bot says so in every
          alternative.
        - No markdown, no invented detail, no greeting or sign-off.
        - Vary the wording, not the meaning or the register. Every line, and every alternative of
          it, must read as the same bot.
        - Return one entry per line you were given, echoing its key back unchanged.
      TEXT
    end

    def user_prompt
      lines = @keys.map { |key| "#{key}\n\"#{original_line(key)}\"" }

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
                  enum: @keys,
                  description: "The key of the line these rewordings replace."
                },
                variants: {
                  type: "array",
                  items: { type: "string" },
                  description: "#{@variant_count} interchangeable rewordings of that line."
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
