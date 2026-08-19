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

    # Set the open submission aside rather than discard it. Called by the tools
    # that take the citizen somewhere else — the menu, a new submission — where
    # the alternative used to be refusing them ("you are in the middle of
    # something") or silently dropping what they had written. Parked, the way
    # back is one `resume_parked` pill, which the assistant is told about in its
    # state.
    #
    # A no-op when there is nothing open, so a caller never has to ask first.
    def park_open_flow!
      return if conversation.idle? && conversation.draft_resource.blank?

      ::Whatsapp::AiAssistant::DecisionLog.record(
        event: :flow_parked, conversation: conversation, step: conversation.step, by: name
      )

      conversation.park_flow!
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

      return unknown_projekt_error(projekt_name) if projekt.blank?

      yield(projekt)
    end

    # What a contribution search hands back when it cannot decide on its own.
    # Shared because two tools now resolve one from what the citizen called it —
    # supporting a proposal and opening any Beitrag — and a second wording of the
    # same refusal is a second situation for the router to tell apart.
    #
    # Reads the same four things off a proposal and off a budget investment:
    # Budget::Investment delegates projekt_phase to its budget, so neither the
    # class nor the shape has to be branched on here.
    def contribution_candidate_summary(contribution)
      projekt = contribution.projekt_phase&.projekt

      {
        contribution_id: contribution.id,
        title: contribution.title,
        projekt: projekt.present? ? projekt_title(projekt) : nil,
        supports: contribution.cached_votes_up
      }.compact
    end

    def no_proposal_match_error(title)
      {
        error: "No publicly listed proposal matches \"#{title}\". Tell the citizen you could not " \
               "find it and ask for the title as it appears on the projekt page."
      }
    end

    # Its own wording rather than the one above: this search covered proposals
    # and budget investments both, so naming proposals in the refusal would send
    # the model asking after a kind of Beitrag that was already looked for.
    def no_contribution_match_error(title)
      {
        error: "No publicly listed contribution matches \"#{title}\". Tell the citizen you could " \
               "not find it and ask for the title as it appears on the projekt page."
      }
    end

    def unknown_phase_error
      { error: "No open participation phase with that id. Call list_open_phases first." }
    end

    # Deliberately not a guess: the name query only answers when it is certain,
    # so an ambiguous name is a question for the citizen rather than a projekt
    # picked on their behalf.
    #
    # What nearly matched travels with the refusal. Without it the model's only
    # move is to list the whole portal back at someone who named their projekt
    # almost correctly — the names are already resolved and ranked by then, and
    # throwing them away costs the citizen the one question worth asking.
    def unknown_projekt_error(projekt_name = nil)
      suggestions = ::Whatsapp::ProjektByNameQuery.suggestions(term: projekt_name.to_s)

      return { error: NO_PROJEKT_ERROR } if suggestions.blank?

      {
        error: NO_PROJEKT_ERROR,
        did_you_mean: suggestions,
        hint: "Ask the citizen whether they meant one of did_you_mean, naming them. Do not act " \
              "on one without their answer."
      }
    end

    NO_PROJEKT_ERROR = "No single project matches that name. Call show_projekts so the citizen " \
                       "can pick one, or ask them to name it exactly.".freeze

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
