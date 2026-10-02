class Ai::Tools::WhatsappAiAssistant::RecordPollAnswer < Ai::Tools::WhatsappAiAssistant::BaseTool
  requires_approval

  # A typed answer to the ballot question the citizen is looking at, recorded the
  # way a tap on the same option is. Whether the message chose that option is the
  # model's reading: the words used to be matched against the options before the
  # model saw them, and a refusal or a contradiction that named an option was
  # stored as a vote for it.
  #
  # Every option of one message goes in one call. The call halts the turn once the
  # ballot's next message is out, so a second call for the second option of "1 und
  # 5" never ran, and the question came back with nothing said about the first.
  description "Records the options the citizen chose for the ballot question in front of " \
              "them, which the state lists numbered and with each option's id. While that " \
              "question is open, a number or an option's words in their message refer to it, " \
              "never to a list shown earlier such as the votes or the contributions. Call it " \
              "only when their latest message clearly chooses — in their own words, or by the " \
              "number the state gives the option — and pass every option it chooses in this " \
              "one call: \"1 und 5\" on a question allowing two is both. On a question allowing " \
              "several, the state marks the options already chosen: one of them named alone " \
              "takes that choice back — pass it so only when they ask to remove it. A message " \
              "that merely contains an option's words is not a choice of it: \"Nein danke, " \
              "ich will gerade nicht abstimmen\" declines to vote rather than voting no, \"Ich bin " \
              "gegen eine Senkung der Gebühren\" is against the option that lowers them, and " \
              "\"Ja, aber was passiert mit meinen Daten?\" asks something first. A vote is " \
              "recorded under the citizen's name, so where any part of the message is unclear " \
              "— whether they chose at all, which option a word means, an option the question " \
              "does not have, more than it allows — record nothing and ask them back in one " \
              "sentence that says how to answer. For a weighted question pass the one option " \
              "and the points they gave it. A free-text question is answered through " \
              "record_open_poll_answer instead, and being done choosing through " \
              "finish_poll_question. Say nothing further once the answer has gone through: the " \
              "ballot's next message has already been sent."

  parameters do
    array :question_answer_ids,
      of: :integer,
      description: "The ids of every option they chose, as the ballot question in the state " \
                   "lists them — exactly one for a question that takes one answer"
    optional :weight,
      description: "Only for a weighted question: how many points they gave the option" do
      integer
    end
  end

  def diagnostic_step
    "poll_vote"
  end

  def execute(question_answer_ids:, weight: nil)
    return not_linked_error("vote") if user.blank?

    question = ::Whatsapp::Polls::OwedQuestionQuery.for(conversation: conversation)&.question

    return no_ballot_question_error if question.blank?
    return free_text_question_error if conversation.pending_open_question_id == question.id
    return map_question_error if question.map_points?

    options = chosen_options(question, question_answer_ids)
    refusal = options_refusal(question, options)

    return refusal if refusal.present?

    if options.first.open_answer?
      return ask_for_own_words(options.first)
    end

    if ::Whatsapp::VotableBallotQuery.weighted?(question)
      return record_weight(options.first, weight)
    end

    record_choices(question, options)
  end

  private

    # In the order the model named them, which is the order the citizen did: the
    # line saying what was read back is what they check it against. Nil where any id
    # is not an option of this question, because recording the rest would be a vote
    # for part of what they said.
    def chosen_options(question, question_answer_ids)
      ids = Array(question_answer_ids).map(&:to_i).uniq

      return if ids.empty?

      found = question.question_answers.where(id: ids).index_by(&:id)
      options = ids.filter_map { |id| found[id] }

      return if options.size != ids.size

      options
    end

    def options_refusal(question, options)
      if options.blank?
        unknown_option_error
      elsif options.size > 1 && !question.multiple?
        single_option_error
      elsif options.size > 1 && options.any?(&:open_answer?)
        own_words_alone_error
      end
    end

    def record_choices(question, options)
      recording = ::Whatsapp::Polls::RecordAnswerService.new(
        conversation: conversation, question_answers: options
      )

      if recording.withdrawal?
        announce_withdrawal(options.first.title)
      elsif recording.room?
        announce(options.map(&:title).join(", "))
      else
        return over_maximum_error(question)
      end

      ballot_answer_outcome(recording.call, poll: question.poll)
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
        conversation: conversation, question_answers: [option]
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

    # The reading said the same way when it takes a choice back, which a citizen
    # who wrote "die 1 doch nicht" has no pill to see the result of.
    def announce_withdrawal(title)
      ::Whatsapp::Send.locale_text(
        account: account,
        body: ::Whatsapp.copy("whatsapp.bot.poll.typed_answer_withdrawn", answer: title)
      )
    end

    def unknown_option_error
      { error: "Not every id is an option of the ballot question in front of the citizen, so " \
               "nothing was recorded. Take the ids from the options the state lists — never " \
               "guess one. Where their message named something the question does not offer, " \
               "ask them back." }
    end

    def single_option_error
      ballot_ask_back_error("This question takes one answer, and the message was read as several.")
    end

    def own_words_alone_error
      ballot_ask_back_error(
        "The option that stands for the citizen's own words is answered on its own, not " \
        "together with other options."
      )
    end

    # The maximum counted with what the citizen already chose, which the state lists:
    # "1 und 5" after an earlier choice on a question allowing two is three.
    def over_maximum_error(question)
      ballot_ask_back_error(
        "Together with what they already chose, that is more than the " \
        "#{question.max_votes} options this question allows. To choose another, they take " \
        "one of their choices back first."
      )
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
