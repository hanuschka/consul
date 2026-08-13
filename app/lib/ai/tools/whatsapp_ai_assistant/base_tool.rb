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

    # Everything open, so a projekt a citizen names is still found when it sits
    # past the row a list would stop at. Which of the two a tool wants is the
    # difference between "what can I show" and "what is there".
    def all_open_projekt_phases
      @all_open_projekt_phases ||= ::Whatsapp::EligiblePhasesQuery.uncapped
    end

    def open_projekt_phases
      all_open_projekt_phases.first(::Whatsapp::MAX_LIST_ROWS)
    end

    # The phase whose projekt the citizen named, resolved against everything open
    # rather than against the listed rows. Matching is
    # Whatsapp::ProjektByNameQuery's — exact wins, a partial only when it is the
    # single one — so an ambiguous name resolves to nothing and is asked about
    # rather than guessed at.
    def named_open_phase(projekt_name)
      projekt = ::Whatsapp::ProjektByNameQuery.call(
        term: projekt_name, candidates: all_open_projekt_phases.map(&:projekt)
      )

      return if projekt.blank?

      all_open_projekt_phases.find { |projekt_phase| projekt_phase.projekt_id == projekt.id }
    end

    def projekt_title(projekt)
      ::Whatsapp::ProjektLink.title(projekt)
    end

    def projekt_url(projekt)
      ::Whatsapp::ProjektLink.url(projekt)
    end

    # Resolved by name rather than by phase id, because what the read tools are
    # asked about is routinely a projekt that has finished: it has no open phase,
    # so no listing tool could have handed the model an id for it first.
    def readable_projekt(projekt_name)
      ::Whatsapp::ProjektByNameQuery.readable(term: projekt_name)
    end

    # The three-way answer every read tool with an optional projekt owes: nothing
    # named is the whole portal, a name that resolves is that projekt, and a name
    # that does not is an error the model can act on. Without the third case a
    # misheard name would be answered portal-wide, which reads as an answer about
    # the projekt the citizen asked after.
    def for_named_projekt(projekt_name)
      return yield(nil) if projekt_name.blank?

      projekt = readable_projekt(projekt_name)

      return unknown_projekt_error if projekt.blank?

      yield(projekt)
    end

    def unknown_phase_error
      { error: "No open participation phase with that id. Call list_open_phases first." }
    end

    # Deliberately not a guess: the name query only answers when it is certain,
    # so an ambiguous name is a question for the citizen rather than a projekt
    # picked on their behalf.
    def unknown_projekt_error
      { error: "No single project matches that name. Call show_projekts so the citizen can " \
               "pick one, or ask them to name it exactly." }
    end

    # These reach the model, not the citizen, so one wording per rule matters
    # more than it looks: three phrasings of "this number is not linked" is
    # three chances for the router to treat them as three different situations.
    def not_linked_error(action)
      { error: "This number is not linked to an account, so it cannot #{action}. Offer to " \
               "link the account first." }
    end

    def no_proposal_error(verb)
      { error: "This conversation is not about a specific proposal, so there is nothing to " \
               "#{verb}. Ask which proposal they mean." }
    end
end
