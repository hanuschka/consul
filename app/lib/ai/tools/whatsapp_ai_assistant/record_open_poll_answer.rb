class Ai::Tools::WhatsappAiAssistant::RecordOpenPollAnswer < Ai::Tools::WhatsappAiAssistant::BaseTool
  # The citizen's words as the answer to the free-text ballot question they were
  # asked. Any message used to be taken as that answer, a question about the
  # ballot included; whether this one is the answer is now the model's reading.
  description "Records the citizen's answer to the free-text ballot question in front of them — " \
              "the state says when one is waiting for their own words. Call it only when " \
              "their latest message is that answer. A question about the vote, such as \"Wie " \
              "lange läuft die Umfrage noch?\", a refusal or a side remark is not: answer it " \
              "and record nothing, and the question is put to them again after your reply. " \
              "Pass their words complete and unchanged — never your summary of them: the " \
              "answer is stored as they wrote it. Say nothing further once it has gone " \
              "through: the ballot's next message has already been sent."

  params do
    string :text,
      description: "What the citizen wrote as their answer, word for word. Never a paraphrase."
  end

  def diagnostic_step
    "poll_vote"
  end

  def execute(text:)
    return not_linked_error("vote") if user.blank?

    question = ::Poll::Question.find_by(id: conversation.pending_open_question_id)

    return no_ballot_question_error if question.blank?

    outcome = ::Whatsapp::Polls::RecordOpenAnswerService.call(
      conversation: conversation, text: text
    )

    ballot_answer_outcome(outcome, poll: question.poll)
  end
end
