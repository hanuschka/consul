class Ai::Tools::WhatsappAiAssistant::BaseTool < RubyLLM::Tool
  def initialize(conversation:)
    @conversation = conversation
  end

  # RubyLLM derives the exposed name from the full class path, which would put
  # the longer names in this namespace past the 64-character limit providers
  # enforce on a function name.
  def name
    self.class.name.demodulize.underscore
  end

  private

    attr_reader :conversation

    def account
      conversation.whatsapp_account
    end

    def user
      account.user
    end

    # Checked one phase at a time rather than by searching the ten-row display
    # list: an eleventh open phase is still open, and a model that guessed an id
    # is stopped by the eligibility rule itself, not by the list's length.
    def eligible_phase(projekt_phase_id)
      projekt_phase =
        ::ProjektPhase.includes(:settings, projekt: :page).find_by(id: projekt_phase_id.to_i)

      return if !::Whatsapp::EligiblePhasesQuery.eligible?(projekt_phase)

      projekt_phase
    end

    def open_projekt_phases
      @open_projekt_phases ||= ::Whatsapp::EligiblePhasesQuery.call
    end

    def projekt_title(projekt)
      ::Whatsapp::ProjektLink.title(projekt)
    end

    def projekt_url(projekt)
      ::Whatsapp::ProjektLink.url(projekt)
    end

    def unknown_phase_error
      { error: "No open participation phase with that id. Call list_open_phases first." }
    end

    # These reach the model, not the citizen, so one wording per rule matters
    # more than it looks: three phrasings of "this number is not linked" is
    # three chances for the router to treat them as three different situations.
    # Only the opening is shared. What follows differs by tool, and for unlink it
    # must not suggest linking — that is the opposite of what was asked for.
    def not_linked_error(rest)
      { error: "This number is not linked to an account, so #{rest}" }
    end

    def no_proposal_error(verb)
      { error: "This conversation is not about a specific proposal, so there is nothing to " \
               "#{verb}. Ask which proposal they mean." }
    end
end
