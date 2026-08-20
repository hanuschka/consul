class Whatsapp::AiAssistant::BotCopyService < ApplicationService
  # The bot's own fixed lines, written in whatever language the citizen is writing in.
  #
  # The assistant's replies follow the citizen because the prompt tells them to, and a
  # model writes any language it is asked for. The lines Ruby sends itself cannot:
  # they are locale copy, and the bot's copy exists in German and English only. A
  # citizen holding the whole conversation in Turkish was still told about consent,
  # about picture rights and about having been unsubscribed in German.
  #
  # Nothing is stored on the citizen and nothing is detected up front. The language is
  # read from their last typed message, which is what makes a number that switches
  # language switch the bot with it — a remembered locale would have to be unlearned,
  # and the one thing it would be remembered from is the message that has already been
  # answered.
  #
  # Every line of one message travels in a single call: a body and the labels of the
  # buttons under it are one thing the citizen reads, and translated apart they drift
  # into two registers.
  #
  # The copy as written is the answer whenever anything is missing, slow or wrong.
  # There is no path here that leaves a message unsent — a German sentence a citizen
  # can paste into a translator beats silence, and several of these lines are the ones
  # that must arrive whatever else fails.
  #
  # ── What the cache is for ───────────────────────────────────────────────────
  # There are perhaps twenty of these lines in the whole bot and they never vary, so
  # after the first citizen to write Turkish has paid for each one, nobody pays again:
  # the answer is keyed by the line's own digest, so editing the locale copy misses on
  # its own rather than needing anything cleared.
  #
  # The language is cached against the digest of the message it was read from, which
  # is the cheapest correct way to make the second send of one turn free — every send
  # in a turn reads the same last inbound message, so the second one finds the
  # language already answered. Deliberately not held on the conversation: a per-turn
  # memo that outlives its turn is a citizen answered in the language of a message
  # they sent last week, and the short life below is what keeps that from happening.
  #
  # Both together mean the warm path — a known language, lines already seen — sends
  # nothing at all. A single line still uncached translates the whole message rather
  # than the missing part of it, for the reason above: these lines are read together.

  TIMEOUT_SECONDS = 8

  MAX_REFERENCE_LENGTH = 500

  FEATURE = "whatsapp.bot_copy".freeze

  # The line cache outlives any conversation; the language cache is a turn's memo and
  # is sized as one, with room for the citizen who answers a question after lunch.
  LINE_CACHE_TTL = 30.days
  LANGUAGE_CACHE_TTL = 6.hours

  CACHE_NAMESPACE = "whatsapp/bot_copy".freeze

  INSTRUCTIONS = <<~TEXT.strip
    You are given a citizen's own message and the lines a chat bot is about to send
    them. Return those lines written in the language the citizen's message is written
    in, and the ISO 639-1 code of that language. When the lines are already in that
    language, return them unchanged.

    Return exactly as many lines as you were given, in the same order, and nothing
    else. Translate faithfully: same meaning, same information, same formal or
    informal register, nothing added, nothing left out, nothing softened.

    Never translate a name. URLs, e-mail addresses, phone numbers and every proper
    name — the portal's, a projekt's, a person's — are reproduced character for
    character, and so are any *bold* or _italic_ marks around them. A portal called
    "Demokratie.Today" is called that in every language.

    Some of these lines are legal notices — about automated replies, about consent,
    about privacy, about who holds the rights to a picture. They carry the same weight
    in the new language as in the one they were written in, so nothing in them may be
    dropped, shortened or paraphrased away.

    A line that is a button label has at most 20 characters to fit in, so keep those
    as short as the original.
  TEXT

  SCHEMA = {
    type: "object",
    properties: {
      language: {
        type: "string",
        description: "Lowercase ISO 639-1 code of the language the citizen's message is in"
      },
      lines: {
        type: "array",
        items: { type: "string" },
        description: "The given lines, in order, written in the citizen's language"
      }
    },
    required: %w[language lines],
    additionalProperties: false
  }.freeze

  # For the common caller, which has one sentence and wants one back.
  def self.line(account:, body:)
    call(account: account, lines: [body]).first
  end

  def initialize(account:, lines:)
    @account = account
    @lines = Array(lines).map(&:to_s)
  end

  def call
    return @lines if @lines.empty?
    return @lines if reference_text.blank?

    remembered = remembered_lines

    return remembered if remembered.present?
    return @lines if !::Ai::Settings.ai_available?

    rewritten_lines
  rescue StandardError => e
    report(e)

    @lines
  end

  private

    # Nothing at all until the turn knows which language it is in: without one there
    # is no key to read the lines under, and the call that would produce the key
    # produces the lines with it.
    def remembered_lines
      language = remembered_language

      return if language.blank?

      lines = @lines.map { |line| Rails.cache.read(line_cache_key(line, language)) }

      return if lines.any?(&:blank?)

      lines
    end

    def rewritten_lines
      answer = ::Ai::SingleTurn.fast_json(
        schema: SCHEMA,
        instructions: INSTRUCTIONS,
        input: input,
        timeout_seconds: TIMEOUT_SECONDS,
        feature: FEATURE
      )

      lines = Array(answer["lines"] || answer[:lines]).map { |line| line.to_s.strip }.compact_blank

      # A short answer would put one line's text under another's, so the whole message
      # falls back rather than half of it: a body carrying a button's label is worse
      # than a body in the wrong language. Nothing is remembered from an answer that
      # did not hold together either.
      return @lines if lines.size != @lines.size

      remember(language_from(answer), lines)

      lines
    end

    def language_from(answer)
      (answer["language"] || answer[:language]).to_s.strip.downcase.first(8).presence
    end

    def remember(language, lines)
      return if language.blank?

      Rails.cache.write(language_cache_key, language, expires_in: LANGUAGE_CACHE_TTL)

      @lines.zip(lines).each do |original, rewritten|
        Rails.cache.write(line_cache_key(original, language), rewritten, expires_in: LINE_CACHE_TTL)
      end
    end

    def remembered_language
      Rails.cache.read(language_cache_key)
    end

    def language_cache_key
      "#{CACHE_NAMESPACE}/language/#{digest(reference_text)}"
    end

    # The line's own digest rather than its i18n key: the caller has already rendered
    # it, interpolations and all, and a portal that renames itself must not keep
    # serving the old name in nine languages.
    def line_cache_key(line, language)
      "#{CACHE_NAMESPACE}/line/#{language}/#{digest(line)}"
    end

    def digest(value)
      Digest::SHA256.hexdigest(value.to_s)
    end

    def input
      { citizen_message: reference_text, lines: @lines }.to_json
    end

    # The last thing the citizen typed, and only that. A tapped button's label is the
    # bot's own words coming back, a caption is not always in the language of the
    # person who sent the picture, and a voice note's transcript is never written to
    # the row — so a turn holding none of these has nothing to read and keeps the copy
    # as written.
    def reference_text
      return @reference_text if defined?(@reference_text)

      @reference_text =
        @account
          .whatsapp_messages
          .where(direction: "inbound", kind: "text")
          .order(created_at: :desc)
          .limit(1)
          .pick(:body)
          .to_s
          .squish
          .truncate(MAX_REFERENCE_LENGTH)
    end

    def report(exception)
      Rails.logger.error(
        "[Whatsapp] bot copy translation failed: #{exception.class} - #{exception.message}"
      )

      Sentry.capture_exception(exception, extra: { whatsapp_account_id: @account&.id })
    end
end
