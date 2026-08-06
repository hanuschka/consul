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

    # Every id the model can hold came out of this list, so resolving through
    # it again is also what stops a guessed id from reaching a phase the bot
    # does not serve.
    def eligible_phase(projekt_phase_id)
      open_projekt_phases.find { |projekt_phase| projekt_phase.id == projekt_phase_id.to_i }
    end

    def open_projekt_phases
      @open_projekt_phases ||= ::WhatsappEligiblePhasesQuery.call
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
end
