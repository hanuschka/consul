class Whatsapp::NextStepService < ApplicationService
  # The single answer to "what does this conversation need next?", asked after a
  # QR entry, a finished or cancelled flow, a first chat opening and any message
  # that arrives with no step able to handle it.
  #
  # The order is what distinguishes the cases: an open flow is continued, an
  # unanswered phase question is repeated, and only a conversation carrying
  # neither falls through to what is open portal-wide. Callers that must ignore
  # the current flow (the menu button) reset it first, which is also what makes
  # tapping menu abandon the flow rather than silently resume it.
  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    return ask_for_idea if @conversation.projekt_phase.present?
    return ask_phase_choice(pending_projekt, pending_phases) if pending_phases.many?
    return send_nothing_open if open_projekt_phases.empty?
    return start_single_phase(open_projekt_phases.first) if open_projekt_phases.one?

    @conversation.reset_flow!

    ask_phase_choice(nil, open_projekt_phases)
  end

  private

    def ask_for_idea
      Whatsapp::Steps::AskForIdeaService.call(conversation: @conversation)
    end

    # With one open phase there is nothing to choose, so the menu is skipped in
    # favour of the question that would follow it anyway.
    def start_single_phase(projekt_phase)
      @conversation.start_flow!(projekt_phase)

      ask_for_idea
    end

    # The menu button is still worth offering: a phase may open later, and
    # tapping it is how someone re-checks without composing a message.
    def send_nothing_open
      Whatsapp::Steps::MainMenuService.call(
        conversation: @conversation,
        body: I18n.t("whatsapp.bot.no_projekt")
      )
    end

    def ask_phase_choice(projekt, projekt_phases)
      Whatsapp::Steps::AskPhaseChoiceService.call(
        conversation: @conversation,
        projekt: projekt,
        projekt_phases: projekt_phases
      )
    end

    def open_projekt_phases
      @open_projekt_phases ||= Whatsapp::EligiblePhasesQuery.call
    end

    # A pending choice may span the whole portal, in which case no projekt was
    # stored alongside the offered phases.
    def pending_projekt
      @pending_projekt ||= Projekt.find_by(id: @conversation.context["phase_choice_projekt_id"])
    end

    def pending_phases
      @pending_phases ||=
        ProjektPhase
          .where(id: Array(@conversation.context["phase_choice_ids"]))
          .includes(projekt: :page)
          .to_a
    end
end
