class Ai::Tools::WhatsappAiAssistant::BaseTool < RubyLLM::Tool
  # Written once for the five tools that page a capped list. The wording is the
  # whole contract for how a citizen reaches row eleven, so five copies of it are
  # five chances for one of them to describe a different offset.
  FROM_DESCRIPTION = "Which ten of the list to return: leave empty for the first ten, or pass " \
                     "the next_from a previous call returned for the ten after those.".freeze

  def initialize(conversation:)
    @conversation = conversation
  end

  # RubyLLM derives the exposed name from the full class path, which would put
  # the longer names in this namespace past the 64-character limit providers
  # enforce on a function name.
  def name
    self.class.name.demodulize.underscore
  end

  # Which step this tool leaves the conversation looking like, for the diagnostic
  # column and nothing else — no tool reads it back, and the assistant decides
  # what comes next from the state it is told rather than from this. Nil for the
  # reads, which leave the conversation where they found it.
  def diagnostic_step
    nil
  end

  private

    attr_reader :conversation

    def account
      conversation.whatsapp_account
    end

    def user
      account.user
    end

    def projekt_phase
      conversation.projekt_phase
    end

    def draft_resource
      conversation.draft_resource
    end

    # Checked one phase at a time rather than by searching the ten-row display
    # list: an eleventh open phase is still open, and a model that guessed an id
    # is stopped by the eligibility rule itself, not by the list's length.
    def eligible_phase(projekt_phase_id)
      candidate =
        ::ProjektPhase.includes(:settings, projekt: :page).find_by(id: projekt_phase_id.to_i)

      return if !::Whatsapp::EligiblePhasesQuery.eligible?(candidate)

      candidate
    end

    # Everything open, so a projekt a citizen names is still found when it sits
    # past the row a list would stop at. Which of the two a tool wants is the
    # difference between "what can I show" and "what is there".
    def all_open_projekt_phases
      @all_open_projekt_phases ||= ::Whatsapp::EligiblePhasesQuery.uncapped
    end

    def open_projekt_phases(from: 0)
      ::Whatsapp::ListWindow.page(all_open_projekt_phases, from: from)
    end

    # How many phases the bot could take a submission into, per projekt. Grouped
    # off the pass above rather than asked per projekt, because every tool that
    # lists projekts has to say which of them can be contributed to and asking
    # that a row at a time is the most expensive question the bot asks, ten times
    # over for one message.
    def open_phase_counts
      @open_phase_counts ||=
        all_open_projekt_phases.each_with_object(Hash.new(0)) do |projekt_phase, counts|
          counts[projekt_phase.projekt_id] += 1
        end
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

      all_open_projekt_phases.find { |phase| phase.projekt_id == projekt.id }
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
    # Shared because several tools resolve one from what the citizen called it,
    # and a second wording of the same refusal is a second situation for the model
    # to tell apart.
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

    # ── Refusals ────────────────────────────────────────────────────────────
    # These reach the model, not the citizen, so one wording per rule matters
    # more than it looks: three phrasings of "this number is not linked" is three
    # chances for it to treat them as three different situations. Each says what
    # is wrong and what would fix it, because the model's next move is a sentence
    # to the citizen and it has nothing else to write it from.

    def no_proposal_match_error(title)
      {
        error: "No publicly listed proposal matches \"#{title}\". Tell the citizen you could not " \
               "find it and ask for the title as it appears on the projekt page."
      }
    end

    # Its own wording rather than the one above: this search covered proposals and
    # budget investments both, so naming proposals in the refusal would send the
    # model asking after a kind of Beitrag that was already looked for.
    def no_contribution_match_error(title)
      {
        error: "No publicly listed contribution matches \"#{title}\". Tell the citizen you could " \
               "not find it and ask for the title as it appears on the projekt page."
      }
    end

    def unknown_phase_error
      { error: "No open participation phase with that id. Call list_open_phases first." }
    end

    # Deliberately not a guess: the name query only answers when it is certain, so
    # an ambiguous name is a question for the citizen rather than a projekt picked
    # on their behalf.
    #
    # What nearly matched travels with the refusal. Without it the model's only
    # move is to list the whole portal back at someone who named their projekt
    # almost correctly — the names are already resolved and ranked by then.
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

    NO_PROJEKT_ERROR = "No single project matches that name. Call send_list with the projekts " \
                       "so the citizen can pick one, or ask them to name it exactly.".freeze

    def not_linked_error(action)
      { error: "This number is not linked to an account, so it cannot #{action}. Tell the " \
               "citizen an account is needed and call send_login_link when they want one." }
    end

    def no_proposal_error(verb)
      { error: "This conversation is not about a specific proposal, so there is nothing to " \
               "#{verb}. Ask which proposal they mean." }
    end

    # Two situations, and telling them apart matters more than it looks. A draft that
    # has been written but not saved is waiting on something the phase requires, and
    # there is no record for these tools to act on — but answering that with "there is
    # no draft" sends the model back to draft_proposal, which regenerates from scratch
    # and throws away the answers the citizen has already given.
    def no_draft_error
      return unsaved_draft_error if conversation.unsaved_submission?

      { error: "There is no draft in this conversation. Ask the citizen what they want to " \
               "contribute and call draft_proposal with their own words." }
    end

    def unsaved_draft_error
      { error: "The draft is written but not saved yet, because something this phase requires is " \
               "still outstanding — so there is no record to act on. Call draft_status for what " \
               "is missing and record it. Do not call draft_proposal again: that would write a " \
               "new draft and lose what the citizen has already answered." }
    end

    def no_phase_error
      { error: "No participation phase has been chosen for this submission. Call " \
               "list_open_phases and then start_draft before working on a draft." }
    end

    # The gate the retired step machine enforced by sequence and that now has to be
    # enforced by every tool that would violate it. Terms and privacy acceptance is
    # the same checkbox the web form collects, so it is a refusal rather than an
    # instruction: a sentence in the prompt is something a model can talk itself
    # past, and what is on the other side of this one is an unconsented submission
    # published under a citizen's name.
    def refuse_without_consent
      return if account.terms_accepted?

      {
        error: "This citizen has not accepted the terms and the privacy policy, which is a legal " \
               "requirement before anything may be submitted. Show them the two links returned " \
               "here, ask them to accept, and offer the terms_accept button. Nothing can be " \
               "drafted or published until they have.",
        conditions_url: ::Whatsapp::PortalLinks.conditions_url,
        privacy_url: ::Whatsapp::PortalLinks.privacy_url
      }
    end

    # Re-checked per action rather than once when the submission began: the same
    # three tools can be minutes or days apart, and a phase that expires in
    # between must stop an idea before it costs a draft and stop a draft before it
    # becomes a proposal.
    #
    # Returns nil when the citizen may act. The reason travels with the refusal —
    # it is the same symbol the web form's refusal reads — so the model can say
    # which rule stopped them rather than that something did.
    def refuse_if_not_permitted
      return no_phase_error if projekt_phase.blank?

      problem = ::Whatsapp::Drafting::ResourceCreationValidationService.call(
        projekt_phase: projekt_phase,
        user: ::Whatsapp::Drafting::SubmissionAuthorService.call(conversation: conversation)
      )

      return if problem.blank?

      participation_refused_error(problem)
    end

    # What the two taxonomy tools answer with. Shared here rather than written twice
    # because the two differ in nothing but the word: a second wording of "that
    # option is not one this phase offers" is a second situation for the model to
    # tell apart, and the pair would drift the first time one of them was edited.
    def draft_choice_answer(outcome, kind)
      return draft_choice_rejected(outcome.rejected, kind) if outcome.rejected?
      return invalid_draft_error(outcome.errors) if outcome.invalid?
      return draft_choice_incomplete(outcome.missing, kind) if outcome.missing?

      {
        recorded: kind,
        draft_saved: true,
        hint: "Nothing is outstanding. Show them the draft and ask whether it can go in."
      }
    end

    def draft_choice_incomplete(missing, kind)
      {
        recorded: kind,
        still_needed: missing.to_s,
        hint: "The draft still cannot be saved. Ask the citizen for the #{missing} too, offering " \
              "the options draft_status returns."
      }
    end

    def draft_choice_rejected(reason, kind)
      return no_draft_error if reason == :no_draft

      if reason == :not_collected
        return {
          error: "This phase does not collect a #{kind}, so there is nothing to record. Do not " \
                 "ask the citizen about it."
        }
      end

      {
        error: "That is not a #{kind} this phase offers. Call draft_status for the options it " \
               "really has and ask the citizen again — never guess an id."
      }
    end

    def invalid_draft_error(errors)
      {
        error: "The portal refused to save the draft.",
        reason: Array(errors).first.to_s,
        hint: "Their own words are what has to change, so say what the problem is and ask them " \
              "to put it differently. Retrying the same text fails identically."
      }
    end

    def participation_refused_error(reason)
      {
        error: "This citizen may not submit to this phase right now.",
        reason: reason.to_s,
        rule: ::Whatsapp::ParticipationRules.explain(
          reason: reason, projekt_phase: projekt_phase
        )
      }.compact
    end
end
