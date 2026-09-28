class Ai::Tools::WhatsappAiAssistant::RecordPollAnswer < Ai::Tools::WhatsappAiAssistant::BaseTool
  # A typed answer to the ballot question the citizen is looking at, recorded the
  # way a tap on the same option is. Whether the message chose that option is the
  # model's reading: the words used to be matched against the options before the
  # model saw them, and a refusal or a contradiction that named an option was
  # stored as a vote for it.
  description "Records the option the citizen chose for the ballot question in front of them, " \
              "which the state lists together with each option's id. Call it only when their " \
              "latest message actually chooses that option — in their own words, or by the " \
              "number the question printed beside it. A message that merely contains an " \
              "option's words is not a choice of it: \"Nein danke, ich will gerade nicht " \
              "abstimmen\" declines to vote rather than voting no, \"Ich bin gegen eine " \
              "Senkung der Gebühren\" is against the option that lowers them, and \"Ja, aber " \
              "was passiert mit meinen Daten?\" asks something first. A vote is recorded under " \
              "the citizen's name, so where it is unclear whether they chose an option, or " \
              "which one, answer what they wrote and record nothing — the question is put to " \
              "them again after your reply. For a weighted question pass the points they gave " \
              "the option as well. A free-text question is answered through " \
              "record_open_poll_answer instead. Say nothing further once the answer has gone " \
              "through: the ballot's next message has already been sent."

  params do
    integer :question_answer_id,
      description: "The id of the option they chose, as the ballot question in the state lists it"
    optional :weight,
      description: "Only for a weighted question: how many points they gave the option" do
      integer
    end
  end

  def diagnostic_step
    "poll_vote"
  end

  def execute(question_answer_id:, weight: nil)
    return not_linked_error("vote") if user.blank?

    question = ::Whatsapp::Polls::OwedQuestionQuery.for(conversation: conversation)&.question

    return no_ballot_question_error if question.blank?
    return free_text_question_error if conversation.pending_open_question_id == question.id
    return map_question_error if question.map_points?

    option = question.question_answers.find_by(id: question_answer_id.to_i)

    return unknown_option_error if option.blank?
    return ask_for_own_words(option) if option.open_answer?

    if ::Whatsapp::VotableBallotQuery.weighted?(question)
      return record_weight(option, weight)
    end

    record_choice(option)
  end

  private

    def record_choice(option)
      announce(option.title)

      outcome = ::Whatsapp::Polls::RecordAnswerService.call(
        conversation: conversation, question_answer: option
      )

      ballot_answer_outcome(outcome, poll: option.question.poll)
    end

    def record_weight(option, weight)
      return missing_weight_error if weight.blank? || weight.to_i.negative?

      announce("#{option.title}: #{weight.to_i}")

      outcome = ::Whatsapp::Polls::RecordWeightedAnswerService.call(
        conversation: conversation, question_answer: option, weight: weight.to_i
      )

      ballot_answer_outcome(outcome, poll: option.question.poll)
    end

    # An option standing for the citizen's own words records nothing by itself, the
    # same as a tap on it: the question is armed for their words and asks for them.
    def ask_for_own_words(option)
      outcome = ::Whatsapp::Polls::RecordAnswerService.call(
        conversation: conversation, question_answer: option
      )

      ballot_answer_outcome(outcome, poll: option.question.poll)
    end

    # What the bot read goes out before the answer is recorded, which a tap needs no
    # equivalent of: the citizen saw which pill they pressed, where here a sentence
    # has been interpreted for them. It says the reading rather than the result,
    # because the record can still be refused underneath it — a poll closed between
    # two messages, a maximum already spent — and those refusals say their own piece
    # after it without contradicting it.
    def announce(reading)
      ::Whatsapp::Send.locale_text(
        account: account,
        body: ::Whatsapp.copy("whatsapp.bot.poll.typed_answer_read", answer: reading)
      )
    end

    def unknown_option_error
      { error: "That id is not an option of the ballot question in front of the citizen. " \
               "Take the id from the options the state lists — never guess one." }
    end

    def free_text_question_error
      { error: "This question is answered in the citizen's own words, not by choosing an " \
               "option. Where their message is that answer, call record_open_poll_answer." }
    end

    def map_question_error
      { error: "This question is answered by sharing a place on the map, which typing cannot " \
               "do. Ask them to send it with WhatsApp's location button." }
    end

    def missing_weight_error
      { error: "This is a weighted question: pass the points the citizen gave the option, as " \
               "a whole number from zero. Where they have not said how many, ask them." }
    end
end
