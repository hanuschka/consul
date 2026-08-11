class Whatsapp::AiAssistant::CriterionFeedbackService < ApplicationService
  # The evaluation model writes its feedback about the draft — "Der Vorschlag
  # erwähnt schattige Stellen" — which is the wrong thing to say to someone
  # whose Beitrag does not exist yet and who is being asked to change what they
  # themselves just wrote. This restates it to them.
  #
  # Deliberately not fixed in the evaluation prompt: that one is fetched from
  # the DT API and shared with the web proposal and budget-investment flows, so
  # rewording it there would change what those two say to everyone on every
  # portal to solve a WhatsApp wording problem.
  #
  # The fast model, like the intent router: this is one short rewrite on a turn
  # the citizen is already waiting on, not a generation.
  REQUEST_TIMEOUT_SECONDS = 15

  def initialize(criterion_feedback:, idea_text:)
    @criterion_feedback = criterion_feedback.to_s.strip
    @idea_text = idea_text.to_s.strip
  end

  # Always returns something sendable. AI switched off, an unreachable
  # provider, a reply that came back empty — all land on the evaluator's own
  # wording, which is what was shown before this existed.
  def call
    return @criterion_feedback if @criterion_feedback.blank?
    return @criterion_feedback if @idea_text.blank?
    return @criterion_feedback if !::Ai::Settings.ai_available?

    rephrased.presence || @criterion_feedback
  rescue StandardError => e
    Rails.logger.error("[Whatsapp] criterion feedback rephrasing failed: #{e.class} - #{e.message}")

    @criterion_feedback
  end

  private

    def rephrased
      ::Ai::RubyLlmFactory
        .chat_with_request_timeout(
          REQUEST_TIMEOUT_SECONDS,
          gpt_model: ::Ai::Settings::DEFAULT_GPT_FAST_MODEL
        )
        .with_instructions(instructions)
        .ask(user_prompt)
        .content
        .to_s
        .strip
    end

    def instructions
      <<~TEXT
        You rewrite one line of feedback that a citizen participation portal gives about a
        contribution someone is trying to submit over WhatsApp. The original talks about the
        contribution as a finished thing; you write to the person, about what they just asked for.

        Rules:
        - Write in #{output_language}, addressing the citizen #{address_form_instruction}.
        - Open by naming what they asked for, addressed to them — "You mention ...", "You would
          like ..." — in the address form given above. Never quote them back word for word, and
          never repeat their whole message.
        - Then give the reason from the original, rewritten so that it never refers to the
          proposal, the contribution or the Beitrag at all, in any wording. There is no such thing
          yet: that is the whole point of this rewrite.
        - Where the reason is about what they wrote, make them its subject as well — "you do not
          name a specific place" rather than "the contribution names no specific place".
        - Keep the reason itself exactly as it was given. Never soften it, never add one, never
          invent a rule that is not there.
        - Two short sentences at most. No emoji, no markdown, no greeting, no sign-off.
        - Do not tell them what to do next and do not ask a question: the message this line goes
          into already carries the buttons for that.
        - Return the rewritten line and nothing else.
      TEXT
    end

    def user_prompt
      <<~PROMPT
        What the citizen wrote:
        "#{@idea_text}"

        The feedback about it:
        "#{@criterion_feedback}"
      PROMPT
    end

    def address_form_instruction
      ::Whatsapp.address_form_instruction
    end

    def output_language
      ::Ai::OutputLanguage.chat_name_for(I18n.locale)
    end
end
