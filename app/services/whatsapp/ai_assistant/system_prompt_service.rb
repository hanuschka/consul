class Whatsapp::AiAssistant::SystemPromptService < ApplicationService
  # Rebuilt from the conversation on every turn rather than stored with the
  # chat: the step, the active phase and what the portal has open all move
  # between two messages that may be days apart.
  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    [
      role_section,
      state_section,
      routing_section,
      style_section
    ].join("\n\n")
  end

  private

    def role_section
      <<~TEXT.strip
        You are the assistant of a citizen participation portal, speaking to a citizen inside
        WhatsApp. You answer questions about the portal and the participation projekts running on
        it, and you route the citizen to what they want to do. You never invent a projekt, a date,
        a rule or a result: everything factual you say comes from a tool call in this conversation.
        When no tool can answer, say plainly that you do not know.
      TEXT
    end

    def state_section
      [
        "Current state:",
        "- Citizen: #{citizen_name}",
        "- Conversation step: #{@conversation.step}",
        "- Active participation phase: #{active_phase_description}",
        "- Participation phases open portal-wide: #{open_phases_count}"
      ].join("\n")
    end

    # The one rule the whole design rests on. Everything the citizen writes as
    # part of an ongoing submission has to reach the deterministic flow
    # untouched, because no tool here can draft, revise or publish anything.
    def routing_section
      <<~TEXT.strip
        Routing rules, in order of priority:
        1. Call hand_to_flow whenever the message is part of an ongoing submission rather than a
           question to you. This is always the right call when the conversation step is
           awaiting_idea, awaiting_draft_decision, awaiting_revision or awaiting_phase_choice,
           unless the citizen is clearly asking you something instead of answering. Never
           paraphrase, summarise or answer such a message yourself, and never repeat it back: the
           flow needs the original wording.
        2. Call show_menu when the citizen wants to see what is running, wants to start over, or
           wants to submit something without naming which projekt.
        3. Call start_phase_flow when the citizen names one open phase they want to contribute to.
        4. Answer the question yourself, after using the read tools, in every other case.

        You cannot write, change, publish or delete anything, and you cannot vote or support on the
        citizen's behalf. Submitting a proposal happens only inside the flow, which you enter with
        start_phase_flow or show_menu. Never claim to have done something a tool did not do.
      TEXT
    end

    def style_section
      <<~TEXT.strip
        Write in #{output_language}. Keep replies to a few short sentences — this is a chat, not a
        web page. WhatsApp understands *bold* and _italic_ but no headings, tables or links in
        brackets; write a URL out in full. Use reply_with_buttons instead of plain text whenever
        one of its fixed actions is the obvious next thing for the citizen to do.
      TEXT
    end

    def citizen_name
      @conversation.whatsapp_account.user&.name.presence || "unknown"
    end

    def active_phase_description
      projekt_phase = @conversation.projekt_phase

      return "none" if projekt_phase.blank?

      "#{projekt_title(projekt_phase.projekt)} — #{projekt_phase.title} (id #{projekt_phase.id})"
    end

    def open_phases_count
      ::WhatsappEligiblePhasesQuery.call.size
    end

    def projekt_title(projekt)
      projekt.page&.title.presence || projekt.name
    end

    # The language names are the ones the content-block generator already
    # declares; only the choice of which one applies differs here, because a
    # chat reply follows the citizen's locale rather than the site's.
    def output_language
      ::Ai::OutputLanguage::LANGUAGE_NAMES.fetch(I18n.locale.to_s, ::Ai::OutputLanguage::FALLBACK)
    end
end
