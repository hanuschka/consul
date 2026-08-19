class Whatsapp::AiAssistant::ComposeReplyService < ApplicationService
  # One reply of the bot's own copy, written for the conversation it is about to
  # land in. The locale file says what the message *means* — "the submission was
  # abandoned", "this phase is closed", "here is what you can do" — and this
  # writes that meaning as an answer to what the citizen actually just said, at
  # this point in this chat, after this much silence.
  #
  # It replaced WriteMessageService, which did the same job from a narrower desk:
  # it saw the citizen's last message and the step, and nothing else. That was
  # enough to stop the copy reading as a form letter and not enough to make the
  # chat read as a conversation — every reply still began from the same standing
  # start, repeated wordings it had used two messages earlier, and greeted a
  # citizen who had written a minute ago exactly as it greeted one returning
  # after a week (CON-2982). The inputs are the fix; the guardrails below are
  # carried over unchanged, because they are what makes a composed line safe to
  # send at all.
  #
  # Returns nil for anything it will not vouch for, and every caller falls back
  # to the fixed sentence. That is the whole safety story: a provider that is
  # down, slow, or creative costs the portal its fluency, never its correctness.
  #
  # Deliberately not a router: it decides nothing, calls no tool, and cannot
  # change what the message is about. The step the flow is in has already chosen
  # what to say; this only chooses the words.
  REQUEST_TIMEOUT_SECONDS = 8

  # Chat brevity, and a ceiling a runaway answer cannot slip past. Wider than the
  # bare rewrite factor of 2 this replaces, because a composed reply legitimately
  # carries what the fixed line does not: the connective clause back to what was
  # just said, and the options named in the text rather than left behind a button.
  MAX_LENGTH_FACTOR = 3

  # The floor below which there is nothing to compose. A four-word confirmation
  # is already as conversational as it will get, and paying a completion to
  # lengthen it is the opposite of chat brevity.
  MIN_SOURCE_LENGTH = 20

  # An absolute ceiling as well as the relative one: WhatsApp shows roughly this
  # much before "Mehr anzeigen", and a reply that has to be expanded to be read
  # is not a chat message. It bites where the source line is itself long, which
  # is where the factor above stops being a limit.
  MAX_LENGTH = 900

  # The floor when this reply carries tappable options, because then the source
  # line stops predicting the length of the answer. "Möchten Sie noch etwas tun?"
  # is 27 characters, which the factor turns into a ceiling of 81 — and this
  # service simultaneously asks the model to name the options that fit. Every
  # post-publish menu therefore bought a completion and threw it away as
  # :too_long, landing back on the sentence the ticket complains about.
  MIN_LENGTH_WITH_OPTIONS = 320

  # A date in digits is rendered by WhatsApp as a phone number and offers to
  # call it, which is why every date the bot sends is written out in words. The
  # model is told; this is what checks.
  DIGIT_DATE = /\d{1,2}\.\s?\d{1,2}\.\s?\d{2,4}/
  MARKDOWN_LINK = /\[[^\]]*\]\([^)]*\)/
  URL = %r{https?://\S+}

  # The options this reply will carry as taps, so the composed sentence can name
  # them instead of ending on "Was möchten Sie tun?" above a button that hides
  # the answer. Passed in rather than read off the conversation: these are the
  # rows about to be sent, and conversation.offered_options still holds the
  # previous message's.
  def initialize(fixed_text:, context:, offered_labels: [])
    @fixed_text = fixed_text.to_s
    @context = context
    @offered_labels = Array(offered_labels).map(&:to_s).reject(&:blank?)
  end

  def call
    return if !composable?

    @context.count_composition!

    composed = ask

    return record_rejection(:empty) if composed.blank?

    refusal = refusal_reason(composed)

    return record_rejection(refusal) if refusal.present?

    ::Whatsapp::AiAssistant::DecisionLog.record(
      event: :compose_applied, conversation: conversation, length: composed.length
    )

    composed
  rescue StandardError => e
    ::Whatsapp::AiAssistant::DecisionLog.record(
      event: :compose_failed, conversation: @context&.conversation, error: e.class.name
    )

    nil
  end

  private

    def composable?
      return false if @context.blank? || @context.conversation.blank?
      return false if !@context.compositions_left?
      return false if @fixed_text.length < MIN_SOURCE_LENGTH
      return false if !::Ai::Settings.ai_available?

      true
    end

    def ask
      chat = ::Ai::RubyLlmFactory.fast_chat(REQUEST_TIMEOUT_SECONDS)

      chat.with_instructions(instructions)

      chat.ask(@fixed_text).content.to_s.strip
    end

    # Ordered so the static half comes first and the per-turn half last: the role
    # and the rules are identical on every call in the process, and a provider
    # that discounts a repeated prompt prefix can only do so for as long as the
    # prefix holds. Putting the conversation state ahead of them would bust that
    # on every message (see SystemPromptService, ordered the same way and for the
    # same reason).
    def instructions
      [role_instruction, rules_instruction, state_instruction].compact.join("\n\n")
    end

    def role_instruction
      <<~TEXT.strip
        You are writing one message of a citizen participation portal's WhatsApp bot. The line you
        are given is what the bot has to say at this point in the conversation. Say exactly that,
        in your own words, to this citizen at this moment — as the next turn of a conversation you
        have been part of, not as a piece of copy that happens to fit.
      TEXT
    end

    # The citizen's own message is the reason this call exists: it is what lets a
    # refusal name what they asked for and a menu answer the question they opened
    # with, instead of both reading as the form letter they are.
    def state_instruction
      [
        "This conversation:",
        "- The citizen just wrote: #{citizen_message}",
        "- Time since their previous message: #{@context.gap_instruction_line}",
        "- Conversation step: #{conversation.step}",
        "- Projekt on the table: #{phase_description}",
        "- Draft on the table: #{draft_description}",
        offered_labels_section,
        used_phrasings_section,
        transcript_section
      ].compact.join("\n")
    end

    # Named so the reply can put them in its own sentence. The buttons are sent
    # regardless; what this stops is the reply that says nothing about them.
    def offered_labels_section
      return if @offered_labels.blank?

      [
        "- This message will carry these tappable options. Name the ones that fit in your",
        "  sentence, in your own words, so the citizen can read what is on offer without",
        "  tapping. Do not list them as a menu and do not invent any:",
        *@offered_labels.map { |label| "  - #{label}" }
      ].join("\n")
    end

    # What this chat has already had said in it, the bot's own pushed
    # notifications included. It is how a reply can pick up "was war das
    # nochmal?" instead of starting from nothing.
    def transcript_section
      transcript = digest.transcript

      return if transcript.blank?

      [
        "- Already said in this chat, oldest first. Context to refer back to when it helps;",
        "  never answer these again, they have been dealt with:",
        transcript.lines.map { |line| "  #{line.chomp}" }.join("\n")
      ].join("\n")
    end

    def used_phrasings_section
      phrasings = digest.used_phrasings

      return if phrasings.blank?

      [
        "- Wordings you have already used in this chat. Do not reuse them or a close variant;",
        "  say it differently:",
        *phrasings.map { |phrasing| "  - #{phrasing}" }
      ].join("\n")
    end

    # No new facts is the hard rule: everything true in the output has to be true
    # in the input or in the state above. The model is not being asked what to
    # say, only how — a composition that adds a deadline, a projekt or a promise
    # is worse than the fixed sentence it replaced.
    def rules_instruction
      <<~TEXT.strip
        Rules:
        - Write in #{output_language}, addressing the citizen #{address_form_instruction}. The
          portal chose that form, so never switch, whatever form the citizen writes in.
        - Keep the meaning of the line exactly, including whether it is a refusal, a question or
          a confirmation. Never add a fact that is not in the line or the state below: no dates,
          no deadlines, no projekt names, no numbers, no promises about what happens next.
        - Connect to what was said before instead of starting afresh. Do not introduce yourself,
          and do not greet unless the state below says the gap calls for it.
        - Answer what the citizen actually asked. If their message was a question, your reply
          contains its answer — never hand the same question back to them.
        - Copy every web address exactly as it appears, or leave it out entirely. Never write a
          date in digits — spell it out — and never use markdown links or headings.
        - At most #{max_length} characters, ideally well under. This is a chat message.
        - Answer with the message and nothing else: no quotes around it, no explanation, no
          labels, no list of buttons.
      TEXT
    end

    # Which guardrail this composition broke, or nil when it broke none. Named
    # rather than a boolean so the rejection is worth reading: one thrown out for
    # length is a prompt to tighten, one thrown out for a mangled URL is the
    # model rewriting an address it was told to copy.
    #
    # Every URL in the source has to survive verbatim, because the line is often
    # the only place the citizen is given it. A composition that drops one is
    # allowed — the rules say it may — but one that mangles or invents one is
    # thrown away.
    def refusal_reason(composed)
      return :too_long if composed.length > max_length
      return :markdown_link if composed.match?(MARKDOWN_LINK)
      return :digit_date if composed.match?(DIGIT_DATE) && !@fixed_text.match?(DIGIT_DATE)
      return :url_mangled if composed.scan(URL).any? { |url| @fixed_text.exclude?(url) }

      nil
    end

    def record_rejection(reason)
      ::Whatsapp::AiAssistant::DecisionLog.record(
        event: :compose_rejected, conversation: conversation, reason: reason,
        source_length: @fixed_text.length
      )

      nil
    end

    # Both ceilings, because they fail in different directions: the factor keeps
    # a short confirmation from becoming a paragraph, and the absolute keeps a
    # long line from being tripled into something WhatsApp collapses.
    def max_length
      proportional = [
        @fixed_text.length * MAX_LENGTH_FACTOR,
        MIN_SOURCE_LENGTH * MAX_LENGTH_FACTOR,
        options_floor
      ].max

      [proportional, MAX_LENGTH].min
    end

    def options_floor
      return 0 if @offered_labels.blank?

      MIN_LENGTH_WITH_OPTIONS
    end

    # The turn's one digest, off the context, so the system prompt built moments
    # ago and this composition read the same twelve rows from one query.
    def digest
      @context.dialog_digest
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
