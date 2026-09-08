class Ai::Tools::WhatsappAiAssistant::StartPollVote < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Starts voting in the chat on a voting phase's ballot: it sends the citizen the " \
              "first question as buttons and carries them through the rest of the poll one " \
              "question at a time, recording each answer as it is given. Call it whenever a " \
              "citizen says they want to vote, picks a vote out of a list, or asks what is open " \
              "to vote on and there is one — this is what taking part in a vote means now, so " \
              "never hand out the link instead. Takes the projekt_phase_id that " \
              "list_open_polls, list_open_phases and describe_projekt return. Not every poll " \
              "can be asked in a chat: one holding a rating scale, a weighted vote or a map " \
              "point comes back refused with its ballot's address, and that link is then the " \
              "whole answer — send it and say the vote is on the page. Where the number has no " \
              "account yet this sends the login link and picks the vote up again afterwards, so " \
              "do not call send_login_link alongside it. Say nothing further after a successful " \
              "call: the question is already in front of the citizen and anything added talks " \
              "over it."

  params do
    integer :projekt_phase_id,
      description: "The voting phase whose ballot the citizen wants to answer"
  end

  def execute(projekt_phase_id:)
    candidate = ::Whatsapp::EligiblePhasesQuery.reachable(projekt_phase_id)

    return unknown_phase_error if candidate.blank?
    return not_a_voting_phase_error if !candidate.is_a?(::ProjektPhase::VotingPhase)

    started = ::Whatsapp::Polls::OfferBallotService.call(
      conversation: conversation, projekt_phase: candidate
    )

    return ballot_on_the_page_error(candidate) if !started

    # Halts like every tool that sends its own message: the citizen is looking at the
    # question, and a completion after it could only repeat it or answer it for them.
    halt("Sent the first question of the ballot for #{candidate.title}. Each answer is " \
         "recorded as it is given and the next question follows it, so nothing further is " \
         "owed here.")
  end

  def diagnostic_step
    "poll_vote"
  end

  private

    def not_a_voting_phase_error
      {
        error: "That phase is not a vote, so there is no ballot to answer. Call " \
               "describe_projekt for what the phase actually collects, or list_open_polls for " \
               "the votes that are running."
      }
    end

    # The refusal that carries the way through with it, because the model's next move
    # is a sentence and the address is the whole of what it needs to write one. Every
    # reason a ballot cannot be asked here ends the same way for the citizen — the
    # vote is on the page — so the reasons are not enumerated for a model that would
    # only have to translate them into that one sentence anyway.
    def ballot_on_the_page_error(projekt_phase)
      url = ::Whatsapp::ProjektLink.ballot_url(projekt_phase) ||
        ::Whatsapp::ProjektLink.phase_url(projekt_phase)

      return unreachable_ballot_error if url.blank?

      {
        error: "This ballot cannot be asked in a chat — it holds a question needing a control " \
               "a chat has none of, or the citizen may not vote in it from here.",
        ballot_url: url,
        hint: "Call send_link with this address and say the vote is on the page. Do not " \
              "describe the questions and do not try this tool again for this phase."
      }
    end

    def unreachable_ballot_error
      {
        error: "This vote cannot be answered in the chat and there is no address to send the " \
               "citizen to either, because the projekt has no published page. Say the vote is " \
               "not reachable right now."
      }
    end
end
