class Ai::Tools::WhatsappAiAssistant::FinishPollQuestion < Ai::Tools::WhatsappAiAssistant::BaseTool
  requires_approval

  # The done pill under a multiple-choice question, said in words. A typed "Fertig"
  # used to reach no tool at all, so the model could only answer it, and the
  # question came back under the reply as though nothing had been said.
  description "Closes the multiple-choice ballot question in front of the citizen when their " \
              "latest message says they have chosen all they want — \"fertig\", \"das " \
              "reicht\", \"mehr nicht\" — the way the done button under the question does. " \
              "Only for a question the state says allows several options. Where the message " \
              "chooses options as well, record them with record_poll_answer instead; the " \
              "question then comes back with their choices marked and its done button. Say " \
              "nothing further once it has gone through: the ballot's next message has " \
              "already been sent."

  def diagnostic_step
    "poll_vote"
  end

  def execute
    return not_linked_error("vote") if user.blank?

    question = ::Whatsapp::Polls::OwedQuestionQuery.for(conversation: conversation)&.question

    if question.blank?
      return no_ballot_question_error
    end

    if !choosing_from?(question)
      return not_choosing_error
    end

    outcome = ::Whatsapp::Polls::FinishMultipleQuestionService.call(conversation: conversation)

    if outcome == ::Whatsapp::Polls::FinishMultipleQuestionService::NOTHING_CHOSEN
      return nothing_chosen_error
    end

    ballot_answer_outcome(outcome, poll: question.poll)
  end

  private

    # The marker rather than the question's type alone: a weighted question is held
    # open by the same marker and has no done button to say in words.
    def choosing_from?(question)
      question.multiple? && conversation.open_multiple_question_id.to_i == question.id
    end

    def not_choosing_error
      { error: "The ballot question in front of the citizen is not one they choose several " \
               "options from, so there is nothing to close. Answer what they wrote." }
    end

    def nothing_chosen_error
      ballot_ask_back_error(
        "They have not chosen any option for this question yet, and it is not finished " \
        "without one."
      )
    end
end
