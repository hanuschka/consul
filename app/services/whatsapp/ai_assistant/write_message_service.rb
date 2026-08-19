class Whatsapp::AiAssistant::WriteMessageService < ApplicationService
  # One line of the bot's own copy, rewritten for the conversation it is about to
  # land in. The locale file says what the message means — "the submission was
  # abandoned", "this phase is closed", "here is what you can do" — and this
  # writes that meaning as an answer to what the citizen actually just said.
  #
  # Returns nil for anything it will not vouch for, and every caller falls back
  # to the fixed sentence. That is the whole safety story: a provider that is
  # down, slow, or creative costs the portal its variety, never its correctness.
  #
  # Deliberately not a second router: it decides nothing, calls no tool, and
  # cannot change what the message is about. The step the flow is in has already
  # chosen the sentence; this only chooses the words.
  REQUEST_TIMEOUT_SECONDS = 8

  # Chat brevity, and a ceiling that a runaway answer cannot slip past: a
  # rewrite that comes back three times the length of the line it replaces is
  # not the same message any more.
  MAX_LENGTH_FACTOR = 2
  MIN_SOURCE_LENGTH = 20

  # A date in digits is rendered by WhatsApp as a phone number and offers to
  # call it, which is why every date the bot sends is written out in words. The
  # model is told; this is what checks.
  DIGIT_DATE = /\d{1,2}\.\s?\d{1,2}\.\s?\d{2,4}/
  MARKDOWN_LINK = /\[[^\]]*\]\([^)]*\)/
  URL = %r{https?://\S+}

  def initialize(fixed_text:, context:)
    @fixed_text = fixed_text.to_s
    @context = context
  end

  def call
    return if !writable?

    @context.count_rewrite!

    rewritten = ask

    return record_rejection(:empty) if rewritten.blank?

    refusal = refusal_reason(rewritten)

    return record_rejection(refusal) if refusal.present?

    ::Whatsapp::AiAssistant::DecisionLog.record(
      event: :rewrite_applied, conversation: conversation, length: rewritten.length
    )

    rewritten
  rescue StandardError => e
    ::Whatsapp::AiAssistant::DecisionLog.record(
      event: :rewrite_failed, conversation: @context&.conversation, error: e.class.name
    )

    nil
  end

  private

    def writable?
      return false if @context.blank? || @context.conversation.blank?
      return false if !@context.rewrites_left?
      return false if @fixed_text.length < MIN_SOURCE_LENGTH
      return false if !::Ai::Settings.ai_available?

      true
    end

    def ask
      chat = ::Ai::RubyLlmFactory.fast_chat(REQUEST_TIMEOUT_SECONDS)

      chat.with_instructions(instructions)

      chat.ask(@fixed_text).content.to_s.strip
    end

    # The citizen's own message is the reason this call exists: it is what lets
    # a refusal name what they asked for and a menu answer the question they
    # opened with, instead of both reading as the form letter they are.
    def instructions
      [role_instruction, state_instruction, rules_instruction].join("\n\n")
    end

    def role_instruction
      <<~TEXT.strip
        You are rewriting one line of a citizen participation portal's WhatsApp bot so it reads
        as part of this conversation rather than as fixed copy. The line you are given is what
        the bot has to say. Say exactly that, in your own words, to this citizen at this moment.
      TEXT
    end

    def state_instruction
      [
        "The conversation:",
        "- The citizen just wrote: #{citizen_message}",
        "- Conversation step: #{conversation.step}",
        "- Projekt on the table: #{phase_description}",
        "- Draft on the table: #{draft_description}"
      ].join("\n")
    end

    # No new facts is the hard rule: everything true in the output has to be
    # true in the input or in the state above. The model is not being asked what
    # to say, only how — a rewrite that adds a deadline, a projekt or a promise
    # is worse than the fixed sentence it replaced.
    def rules_instruction
      <<~TEXT.strip
        Rules:
        - Write in #{output_language}, addressing the citizen #{address_form_instruction}. The
          portal chose that form, so never switch, whatever form the citizen writes in.
        - Keep the meaning of the line exactly, including whether it is a refusal, a question or
          a confirmation. Never add a fact that is not in the line or the state above: no dates,
          no deadlines, no projekt names, no promises about what happens next.
        - Copy every web address exactly as it appears, or leave it out entirely. Never write a
          date in digits — spell it out — and never use markdown links or headings.
        - At most #{max_length} characters, ideally shorter. This is a chat message.
        - Answer with the rewritten line and nothing else: no quotes around it, no explanation,
          no buttons, no greeting the line did not have.
      TEXT
    end

    # Which guardrail this rewrite broke, or nil when it broke none. Named
    # rather than a boolean so the rejection is worth reading: a rewrite thrown
    # out for length is a prompt to tighten, one thrown out for a mangled URL is
    # the model rewriting an address it was told to copy.
    #
    # Every URL in the source has to survive verbatim, because the line is often
    # the only place the citizen is given it. A rewrite that drops one is
    # allowed — the rule above says it may — but one that mangles or invents one
    # is thrown away.
    def refusal_reason(rewritten)
      return :too_long if rewritten.length > max_length
      return :markdown_link if rewritten.match?(MARKDOWN_LINK)
      return :digit_date if rewritten.match?(DIGIT_DATE) && !@fixed_text.match?(DIGIT_DATE)
      return :url_mangled if rewritten.scan(URL).any? { |url| @fixed_text.exclude?(url) }

      nil
    end

    def record_rejection(reason)
      ::Whatsapp::AiAssistant::DecisionLog.record(
        event: :rewrite_rejected, conversation: conversation, reason: reason,
        source_length: @fixed_text.length
      )

      nil
    end

    def max_length
      [@fixed_text.length * MAX_LENGTH_FACTOR, MIN_SOURCE_LENGTH * MAX_LENGTH_FACTOR].max
    end

    def conversation
      @context.conversation
    end

    def citizen_message
      @context.inbound_text.to_s.squish.presence || "nothing — this message was not asked for"
    end

    def phase_description
      projekt_phase = conversation.projekt_phase

      return "none" if projekt_phase.blank?

      "#{::Whatsapp::ProjektLink.title(projekt_phase.projekt)} — #{projekt_phase.title}"
    end

    def draft_description
      draft = conversation.draft_resource

      return "none" if draft.blank?

      "\"#{draft.title}\""
    end

    def output_language
      ::Ai::OutputLanguage.chat_name_for(I18n.locale)
    end

    def address_form_instruction
      ::Whatsapp.address_form_instruction
    end
end
