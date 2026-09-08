class Whatsapp::Polls::AskQuestionService < ApplicationService
  # One question of a ballot put in front of the citizen: pills where there is
  # something to choose, and a request for their own words where the question asks
  # for text. Answers whether it sent anything, which is what tells the caller a
  # ballot is still running.
  #
  # The three shapes it sends, and what each of them costs:
  #
  # - `unique` is every option as a pill. One tap answers the question and the next
  #   one follows.
  # - `multiple` is the options not yet chosen plus a pill saying the citizen is
  #   done. Each tap records that choice and comes back here for the rest, so the
  #   list shrinks as it goes and the chat never offers the same choice twice — and
  #   it closes on its own at the maximum the portal set, because a citizen who has
  #   spent their last choice has nothing left to be asked.
  # - free text is a sentence asking for the answer, with a way to skip past it.
  #   Nothing is recorded until the words arrive.
  #
  # Both fixed lines the bot adds — where in the ballot this question sits, and how
  # many choices a multiple question allows — go into the citizen's language on
  # their way out. The poll's name and the question's own title do not, for the same
  # reason a contribution's text does not: a ballot answered in a paraphrase of the
  # question is not the ballot that was published.
  # The second entry point, for a question the citizen has just tapped the open
  # option of. It is not reachable through #call — there the question's own shape
  # decides, and a question carrying choices beside its open option is asked as
  # choices first.
  def self.for_open_answer(conversation:, question:)
    new(
      conversation: conversation,
      position: ::Whatsapp::BallotCursorQuery::Position.new(question: question)
    ).ask_for_text
  end

  def initialize(conversation:, position:)
    @conversation = conversation
    @position = position
  end

  def call
    return ask_for_text if free_text_only?

    options = offerable_options

    return false if options.empty?

    return ask_for_choices(options) if question.multiple?

    ask_for_choice(options)
  end

  # The question is armed for a typed answer before it is asked, so a citizen who
  # answers instantly is not racing the write. Cleared by the words arriving, by the
  # skip pill, and by the ballot ending.
  def ask_for_text
    @conversation.clear_open_multiple_question!
    @conversation.store_pending_open_question!(question.id)

    ::Whatsapp::Send.buttons(account: account, body: text_body, buttons: [skip_pill])

    true
  end

  private

    def question
      @position.question
    end

    # A question whose only option is the open one is asked as a sentence to write.
    # Sending its single pill would be a button whose only purpose is to reveal that
    # the real answer has to be typed anyway.
    def free_text_only?
      ::Whatsapp::VotableBallotQuery.free_text_only?(question.question_answers.to_a)
    end

    def all_options
      @all_options ||= ::Whatsapp::VotableBallotQuery.options(question, seed: user.id)
    end

    # What is left to choose. Only a multiple question subtracts anything: a unique
    # one is answered by replacing whatever stands, so its options all stay on
    # offer and a citizen changing their mind taps the new one.
    def offerable_options
      return all_options.to_a if !question.multiple?

      all_options.reject { |option| chosen_titles.include?(option.title) }
    end

    def chosen_titles
      @chosen_titles ||= ::Poll::Answer
        .where(question_id: question.id, author: user)
        .pluck(:answer)
    end

    def ask_for_choice(options)
      @conversation.clear_open_multiple_question!
      @conversation.clear_pending_open_question!

      send_pills(pills(options))
    end

    # Marked as the question still being picked from before the message goes out,
    # because what makes a multiple question different is that its first answer does
    # not finish it — and the cursor, which reads the recorded answers and nothing
    # else, would move past it on the next message without this.
    def ask_for_choices(options)
      @conversation.clear_pending_open_question!
      @conversation.store_open_multiple_question!(question.id)

      send_pills(pills(options) + [done_pill])
    end

    # Buttons while they fit and a list past that, the same fork the projekt card
    # makes. The options carry no descriptions: an option's own wording is the whole
    # of what it says, and a second line under it would be the bot explaining a
    # ballot to the person voting on it.
    def send_pills(rows)
      return send_buttons(rows) if rows.size <= ::Whatsapp::MAX_BUTTONS

      send_list(rows)
    end

    def send_buttons(rows)
      ::Whatsapp::Send.buttons(account: account, body: body, buttons: rows)

      true
    end

    def send_list(rows)
      ::Whatsapp::Send.list(
        account: account,
        body: body,
        button_label: I18n.t("whatsapp.bot.buttons.choose", locale: locale),
        rows: rows
      )

      true
    end

    # Labelled from the option, and resolved on the tap by its id rather than by its
    # label: WhatsApp allows twenty characters on a button title where an option may
    # run to a sentence, and Poll::Answer records the answer as text. Reading the
    # title off the record on the way back is what keeps a cut label from being
    # stored as the vote.
    def pills(options)
      options.filter_map do |option|
        title = ::Whatsapp::AssistantActions.truncated(option.title)

        next if title.blank?

        { id: ::Whatsapp::FlowActions.id_for(action: :poll_answer, param: option.id), title: title }
      end
    end

    def done_pill
      {
        id: ::Whatsapp::FlowActions.id_for(action: :poll_done, param: question.id),
        title: I18n.t("whatsapp.bot.buttons.poll_done", locale: locale)
      }
    end

    def skip_pill
      {
        id: ::Whatsapp::FlowActions.id_for(action: :poll_skip, param: question.id),
        title: I18n.t("whatsapp.bot.buttons.poll_skip", locale: locale)
      }
    end

    # The poll's name above the question because a card or a list may have put the
    # citizen here several messages ago, and a question with no ballot named over it
    # reads as the bot asking something of its own. The count under it because a
    # ballot asked one message at a time otherwise gives no sense of its own length —
    # on the page that is what the progress bar is for.
    def body
      progress, choices = translated(progress_text, choices_text)

      ["*#{question.poll.name}*", progress, question.title, choices].compact_blank.join("\n\n")
    end

    def text_body
      progress, prompt = translated(progress_text, I18n.t("whatsapp.bot.poll.open_prompt"))

      ["*#{question.poll.name}*", progress, question.title, prompt].compact_blank.join("\n\n")
    end

    # Nothing for a ballot of one question: "Frage 1 von 1" over the only thing being
    # asked is a count of nothing.
    def progress_text
      return if @position.total.to_i < 2

      I18n.t("whatsapp.bot.poll.progress", number: @position.number, total: @position.total)
    end

    # How many choices the question allows, which a citizen looking at a list of
    # pills has no other way to know. Poll::Question#max_votes falls back to the
    # number of options where the portal set no maximum, so the sentence is true
    # either way.
    def choices_text
      return if !question.multiple?

      I18n.t("whatsapp.bot.poll.choices", maximum: question.max_votes)
    end

    # One call for the whole message, because BotCopyService rewrites a message's
    # lines together: asked one at a time, the count and the sentence under it can
    # come back in two different languages. A line this message does not want is
    # passed as blank, which the service leaves in place and never spends a
    # translation on.
    def translated(*lines)
      ::Whatsapp::AiAssistant::BotCopyService.call(
        account: account, lines: lines.map(&:to_s)
      )
    end

    def account
      @conversation.whatsapp_account
    end

    def user
      @conversation.user
    end

    def locale
      ::Whatsapp.locale_for(account)
    end
end
