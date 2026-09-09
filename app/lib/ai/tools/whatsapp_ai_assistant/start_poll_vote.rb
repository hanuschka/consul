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
              "do not call send_login_link alongside it. Say nothing further once a question or " \
              "that link has gone out: it is already in front of the citizen and anything added " \
              "talks over it. What leaves you something to say is a vote this citizen already " \
              "took part in earlier — nothing is sent for that, it cannot be answered again, " \
              "and the result says what to do with it."

  params do
    integer :projekt_phase_id,
      description: "The voting phase whose ballot the citizen wants to answer"
  end

  def execute(projekt_phase_id:)
    candidate = ::Whatsapp::EligiblePhasesQuery.reachable(projekt_phase_id)

    return unknown_phase_error if candidate.blank?
    return not_a_voting_phase_error if !candidate.is_a?(::ProjektPhase::VotingPhase)

    outcome = ::Whatsapp::Polls::OfferBallotService.call(
      conversation: conversation, projekt_phase: candidate
    )

    return ballot_on_the_page_error(candidate) if !outcome

    # Four different things can have gone out, and for three of them "sent the first
    # question" is untrue: a vote already taken part in sent no question at all, a ballot
    # that ended before its first question could be asked sent none either, and a number
    # with no account got the login link instead of one. All of them were reported as the
    # first while this read a single truthy value, which left the stored history saying
    # the citizen was looking at a question they had never been sent.
    case outcome
    when ::Whatsapp::Polls::OfferBallotService::ALREADY_VOTED
      already_answered(candidate)
    when ::Whatsapp::Polls::AdvanceBallotService::COMPLETED
      ballot_ended_early(candidate)
    when ::Whatsapp::Polls::OfferBallotService::LOGIN_OFFERED
      login_link_sent
    else
      first_question_sent(candidate)
    end
  end

  def diagnostic_step
    "poll_vote"
  end

  private

    # Halts like every tool that sends its own message: the citizen is looking at the
    # question, and a completion after it could only repeat it or answer it for them.
    def first_question_sent(projekt_phase)
      halt("Sent the first question of the ballot for #{projekt_phase.title}. Each answer is " \
           "recorded as it is given and the next question follows it, so nothing further is " \
           "owed here.")
    end

    # Halts for the same reason: the login link is a message with its own button, and the
    # ballot picks itself up when the citizen comes back from following it.
    def login_link_sent
      halt("This number has no account yet and voting needs one, so the login link went out " \
           "instead of the first question. The ballot is held and begins by itself once they " \
           "have followed it, so do not send the link again and do not describe the questions.")
    end

    # Not a halt, because nothing has been sent and the citizen is owed a reply. The
    # closing line this used to arrive with was the bot's own; what says it now is the
    # turn this result is reported into, which is also what can offer where to go next.
    #
    # Earlier is the word that has to survive into what is said. This used to arrive as
    # the same outcome a ballot finished a second ago arrives as, so the reply thanked
    # the citizen for votes they had just cast on a tap that cast none — and left nothing
    # saying the vote was closed to them, so the same tap could be made again and thanked
    # again.
    def already_answered(projekt_phase)
      {
        status: "The citizen took part in that vote earlier and answered it in full, so there " \
                "was nothing left to ask and nothing has been sent.",
        hint: "Say that they have already voted in it, that the answers they gave then stand " \
              "unchanged and that it cannot be answered a second time — not a thank-you for " \
              "votes just cast, which is not what happened. Then offer what plausibly follows " \
              "for them in *#{::Whatsapp::ProjektLink.title(projekt_phase.projekt)}* — another " \
              "phase that is open, or the results of this one where they are published. Never " \
              "start this vote again."
      }
    end

    # The ballot was begun and ended before a question could go out, which is neither a
    # vote taken part in nor one under way. It is all but unreachable — every question of
    # a poll offered here is a shape the chat can ask, which is what
    # Whatsapp::VotableBallotQuery decides before a word of it is sent — so what it needs
    # is a reply that does not claim either of the other two happened.
    def ballot_ended_early(projekt_phase)
      {
        status: "The ballot could not be put to the citizen after all and no question was " \
                "sent. Nothing of theirs was recorded and nothing has been sent.",
        hint: "Say the vote cannot be answered here right now, without describing its " \
              "questions, and offer what else is open in " \
              "*#{::Whatsapp::ProjektLink.title(projekt_phase.projekt)}*."
      }
    end

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
