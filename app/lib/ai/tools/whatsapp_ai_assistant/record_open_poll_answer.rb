class Ai::Tools::WhatsappAiAssistant::RecordOpenPollAnswer < Ai::Tools::WhatsappAiAssistant::BaseTool
  requires_approval

  # The citizen's words as the answer to the free-text ballot question they were
  # asked. Any message used to be taken as that answer, a question about the
  # ballot included; whether this one is the answer is now the model's reading.
  #
  # What is stored is the message as it arrived, never text the model passes: the
  # model decides whether the message is the answer, and a paraphrase of it would
  # be stored under the citizen's name as words they never wrote.
  description "Records the citizen's latest message as their answer to the free-text ballot " \
              "question in front of them — the state says when one is waiting for their own " \
              "words. Call it only when that message is the answer. A question about the " \
              "vote, such as \"Wie lange läuft die Umfrage noch?\", a refusal or a side remark " \
              "is not: answer it and record nothing, and the question is put to them again " \
              "after your reply. The message is stored exactly as they sent it. Say nothing " \
              "further once it has gone through: the ballot's next message has already been " \
              "sent."

  def diagnostic_step
    "poll_vote"
  end

  def execute
    return not_linked_error("vote") if user.blank?

    question = ::Poll::Question.find_by(id: conversation.pending_open_question_id)

    return no_ballot_question_error if question.blank?
    return no_written_words_error if citizen_words.blank?

    outcome = ::Whatsapp::Polls::RecordOpenAnswerService.call(
      conversation: conversation, text: citizen_words
    )

    ballot_answer_outcome(outcome, poll: question.poll)
  end

  private

    def no_written_words_error
      { error: "The latest message holds no words the citizen wrote — it is a tapped button, " \
               "a scanned code or a photo — so there is nothing to record as their answer. " \
               "Ask them to write it." }
    end
end
