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
  # - a rating scale is its steps as pills, with the portal's own wording for the
  #   lowest and the highest above them. It is a `unique` question in every other
  #   respect, and it is recorded as one.
  # - a weighted question is one choice at a time, named in full, with the numbers
  #   still free for it as the pills. Each tap records that much weight and comes
  #   back here for the next choice, so the question is held open by the same marker
  #   a `multiple` one is held open by.
  # - a map point is WhatsApp's own location picker, which is the one message that
  #   can carry no buttons of its own — so the way past the question follows in a
  #   second short one, the way the drafting flow's picker does it.
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
      position: ::Polls::BallotTraversalQuery::Position.new(question: question)
    ).ask_for_text
  end

  def initialize(conversation:, position:)
    @conversation = conversation
    @position = position
  end

  def call
    return ask_for_location if question.map_points?
    return ask_for_text if free_text_only?
    return ask_for_weight if weighted?

    options = offerable_options

    return false if options.empty?

    return ask_for_choices(options) if question.multiple?

    ask_for_choice(options)
  end

  # The question is armed for a typed answer before it is asked, so a citizen who
  # answers instantly is not racing the write. Cleared by the words arriving, by the
  # skip pill, and by the ballot ending.
  def ask_for_text
    disarm_pending!
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

    def weighted?
      ::Whatsapp::VotableBallotQuery.weighted?(question)
    end

    # The first choice this citizen has given no weight to yet, in the order the
    # portal set. A weight already given is not asked again in the same walk: the
    # page lets a citizen go back and change one, and in a chat that is a new tap on
    # a pill still sitting above.
    def next_unweighted_choice
      all_options.reject { |option| chosen_titles.include?(option.title) }.first
    end

    # What is still free for one choice, from the query the portal refuses a write
    # against — so the pills cannot offer a number the write would then reduce. Read
    # once per choice: the pills and the sentence above them are the same question
    # asked twice, and it costs the citizen's rows for this question each time.
    def remaining_weights_for(choice)
      @remaining_weights_for ||= {}
      @remaining_weights_for[choice.id] ||= begin
        free = ::Polls::AnswerAllowanceQuery.remaining_weight(
          question: question, user: user, title: choice.title
        )

        (0..free.to_i).to_a
      end
    end

    def ask_for_choice(options)
      disarm_pending!

      send_pills(pills(options), body: body)
    end

    # One choice of a weighted question, with the weight still free for it as the
    # numbers to tap. The question is marked as still being picked from for the same
    # reason a multiple one is: its first recorded weight is not the end of it, and
    # the walk, which reads the recorded answers, would move past it on the next
    # message without this.
    #
    # Which choice a weight belongs to is not written down anywhere, because the pill
    # carries it: a tap names an option and a number together, and nothing else about
    # a weighted question cannot be read back off the answers already recorded.
    def ask_for_weight
      choice = next_unweighted_choice

      return false if choice.blank?

      weights = remaining_weights_for(choice)

      return false if weights.size < 2

      disarm_pending!
      @conversation.store_open_multiple_question!(question.id)

      send_pills(weight_pills(choice, weights), body: weight_body(choice))
    end

    # WhatsApp's own picker, which is the only way to get a position out of a chat.
    # It takes no buttons, so the way past the question follows in a message of its
    # own — a citizen with no place to give would otherwise have to work out that
    # there is no way on, and the question would be put again after every message.
    def ask_for_location
      disarm_pending!
      @conversation.store_pending_map_question!(question.id)

      ::Whatsapp::Send.location_request(account: account, body: location_body)

      offer_to_skip_location

      true
    end

    # The pill's own send, and its label goes through the same one translation call
    # as the sentence above it: a line in the citizen's language over a button in the
    # portal's is the split every send here exists to avoid.
    def offer_to_skip_location
      written_label = I18n.t("whatsapp.bot.buttons.poll_skip", locale: locale)
      body, label = translated(I18n.t("whatsapp.bot.poll.location_optional"), written_label)

      ::Whatsapp::Send.buttons(
        account: account,
        body: body,
        buttons: [
          {
            id: ::Whatsapp::FlowActions.id_for(action: :poll_skip, param: question.id),
            title: ::Whatsapp::AssistantActions.fitting_label(
              translated: label, original: written_label
            )
          }
        ]
      )
    end

    # Exactly one question can be waiting for something that is not a tap — words or
    # a position — so arming either disarms the rest. One call rather than a clear
    # beside every store: a clear left out is a message taken as the answer to a
    # question that is no longer being asked.
    def disarm_pending!
      @conversation.clear_open_multiple_question!
      @conversation.clear_pending_open_question!
      @conversation.clear_pending_map_question!
    end

    # Marked as the question still being picked from before the message goes out,
    # because what makes a multiple question different is that its first answer does
    # not finish it — and the cursor, which reads the recorded answers and nothing
    # else, would move past it on the next message without this.
    def ask_for_choices(options)
      @conversation.clear_pending_open_question!
      @conversation.store_open_multiple_question!(question.id)

      send_pills(pills(options) + [done_pill], body: body)
    end

    # Buttons while they fit and a list past that, the same fork the projekt card
    # makes. The options carry no descriptions: an option's own wording is the whole
    # of what it says, and a second line under it would be the bot explaining a
    # ballot to the person voting on it.
    def send_pills(rows, body:)
      return send_buttons(rows, body: body) if rows.size <= ::Whatsapp::MAX_BUTTONS

      send_list(rows, body: body)
    end

    def send_buttons(rows, body:)
      ::Whatsapp::Send.buttons(account: account, body: body, buttons: rows)

      true
    end

    def send_list(rows, body:)
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

    # Nothing up to whatever is still free for this choice, as its own pill each.
    # Zero is offered rather than left out: a choice the citizen wants to give
    # nothing to still has to be answered for the walk to move past it.
    def weight_pills(choice, weights)
      weights.map do |weight|
        {
          id: ::Whatsapp::FlowActions.id_for(
            action: :poll_weight, param: "#{choice.id}_#{weight}"
          ),
          title: weight.to_s
        }
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

      [
        "*#{question.poll.name}*", progress, question.title, scale_text, choices
      ].compact_blank.join("\n\n")
    end

    # What the two ends of a rating scale mean, which the page prints to the left and
    # the right of the row of steps. The steps arrive in a chat as a column of pills
    # with no ends to print anything at, so the wording goes above them.
    #
    # Out of the translation call, like the question's own title: the labels are the
    # portal's wording for what a step means, and a scale answered against a
    # paraphrase of them is not the scale that was published. Only the sentence
    # around them is the bot's, and it is asked for in the citizen's language
    # directly.
    def scale_text
      return if !question.rating_scale?

      minimum = question.votation_type&.min_rating_scale_label
      maximum = question.votation_type&.max_rating_scale_label

      return if minimum.blank? || maximum.blank?

      I18n.t("whatsapp.bot.poll.scale", minimum: minimum, maximum: maximum, locale: locale)
    end

    def text_body
      progress, prompt = translated(progress_text, I18n.t("whatsapp.bot.poll.open_prompt"))

      ["*#{question.poll.name}*", progress, question.title, prompt].compact_blank.join("\n\n")
    end

    # The choice under the question rather than beside the numbers: a weight pill
    # carries a digit and nothing else, so the only place the citizen can read what
    # they are weighting is the message above them. At full length, and out of the
    # translation call, because it is the poll's own wording like the question's.
    def weight_body(choice)
      progress, prompt = translated(progress_text, weight_prompt_text(choice))

      [
        "*#{question.poll.name}*", progress, question.title, "*#{choice.title}*", prompt
      ].compact_blank.join("\n\n")
    end

    def weight_prompt_text(choice)
      I18n.t(
        "whatsapp.bot.poll.weight_prompt",
        maximum: remaining_weights_for(choice).last
      )
    end

    # How many points are still wanted, which on the page is what the counter beside
    # the map says. A question asking for one is left to say nothing: "1 of 1" over a
    # single pin is a count of nothing.
    def location_body
      progress, prompt = translated(progress_text, location_prompt_text)

      ["*#{question.poll.name}*", progress, question.title, prompt].compact_blank.join("\n\n")
    end

    def location_prompt_text
      return I18n.t("whatsapp.bot.poll.location_prompt") if question.max_map_points < 2

      I18n.t(
        "whatsapp.bot.poll.location_prompt_remaining",
        remaining: question.max_map_points - placed_map_points
      )
    end

    def placed_map_points
      ::Poll::Answer::MapPoint
        .for_question(question)
        .where(poll_answers: { author_id: user.id })
        .count
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
