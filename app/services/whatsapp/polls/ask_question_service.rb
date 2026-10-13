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
  # - `multiple` is every option plus a pill saying the citizen is done, with the
  #   ones already chosen marked. A tap on an option records it, a tap on a marked
  #   one takes it back, and either comes back here — so the numbers the citizen
  #   reads never move under them. Reaching the maximum the portal set does not close
  #   it: the question comes back once more saying so, and only the done pill moves
  #   the ballot on, so the last choice can still be taken back.
  # - free text is a sentence asking for the answer, with a way to skip past it.
  #   Nothing is recorded until the words arrive.
  # - a rating scale is its steps as pills, with what its two ends mean above them
  #   and under its first and last step — the portal's own wording where it set
  #   one, the bot's plain "lowest" and "highest" where it did not. It is a `unique`
  #   question in every other respect, and it is recorded as one.
  # - a weighted question is one choice at a time, with every choice of it listed and
  #   the one being weighted marked, and the numbers still free for it as the pills.
  #   Each tap records that much weight and comes back here for the next choice, so
  #   the question is held open by the same marker a `multiple` one is held open by.
  # - a map point is WhatsApp's own location picker, which is the one message that
  #   can carry no buttons of its own — so the way past the question follows in a
  #   second short one, the way the drafting flow's picker does it.
  #
  # Wherever the options do not fit three buttons, WhatsApp puts them behind a picker
  # the citizen has to open to see what there is to choose from — so the message
  # prints them itself, numbered, and the pills carry the same numbers. The number is
  # what pairs a title cut at twenty characters with its full wording above.
  #
  # The fixed lines the bot adds — where in the ballot this question sits, how many
  # choices a multiple question allows, and where the answer is given — go into the
  # citizen's language on their way out. The poll's name, the question's own title
  # and the options do not, for the same reason a contribution's text does not: a
  # ballot answered in a paraphrase of the question is not the ballot that was
  # published.
  # The second entry point, for a question the citizen has just tapped the open
  # option of. It is not reachable through #call — there the question's own shape
  # decides, and a question carrying choices beside its open option is asked as
  # choices first.
  CHOSEN_MARK = "✓".freeze

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

    options = titled_options

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

  # What the message asking this question offers, in the order it prints and
  # numbers them — read by the assistant's state, so a typed "2" names the option
  # the message numbered 2. A weighted question shows every choice it holds.
  def offered_options
    return all_options if weighted?

    titled_options
  end

  # Whether an option of a multiple question is among the citizen's choices, which
  # the message marks and the assistant's state names — the two have to agree on
  # it, or a typed number taking a choice back reads as one adding it.
  def chosen?(option)
    question.multiple? && chosen_titles.include?(option.title)
  end

  # The first choice this citizen has given no weight to yet, in the order the
  # portal set. A weight already given is not asked again in the same walk: the
  # page lets a citizen go back and change one, and in a chat that is a new tap on
  # a pill still sitting above.
  def next_unweighted_choice
    all_options.reject { |option| chosen_titles.include?(option.title) }.first
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

    # An option with no wording has nothing to put on a pill and nothing to read in
    # the message, so it drops out before either is built. Both are numbered from
    # this one list: a line numbered against a pill that was never sent points the
    # citizen at a choice they cannot make.
    def titled_options
      all_options.select { |option| option.title.to_s.squish.present? }
    end

    def chosen_titles
      @chosen_titles ||= ::Poll::Answer
        .where(question_id: question.id, author: user)
        .pluck(:answer)
    end

    def weighted?
      ::Whatsapp::VotableBallotQuery.weighted?(question)
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

      offer_choices(options, closing_rows: [])
    end

    # What the message says depends on how its rows will arrive, so the count comes
    # first. Three of them are buttons printing their own wording, where the message
    # has nothing to add and the pills nothing to be paired with — a number there
    # would spend three of the twenty characters a label has on nothing. Past three
    # WhatsApp puts the rows behind its picker, and then the options are printed in
    # the message and the pills carry the numbers that pair the two.
    #
    # A multiple question's closing pill counts towards the three the way an option
    # does, which is why it arrives here rather than being appended further down.
    def offer_choices(options, closing_rows:)
      if ::Whatsapp.buttons?(options.size + closing_rows.size)
        return send_pills(pills(options) + closing_rows, body: body([]))
      end

      send_pills(numbered_pills(options) + closing_rows, body: body(options))
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
      written_label = ::Whatsapp.copy("whatsapp.bot.buttons.poll_skip", locale: locale)
      body, label = translated(::Whatsapp.copy("whatsapp.bot.poll.location_optional"), written_label)

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
    #
    def ask_for_choices(options)
      @conversation.clear_pending_open_question!
      @conversation.store_open_multiple_question!(question.id)

      offer_choices(options, closing_rows: [done_pill])
    end

    # Buttons while they fit and a list past that, the same fork the projekt card
    # makes. The options carry no descriptions of the bot's: an option's own wording
    # is the whole of what it says, and a second line under it would be the bot
    # explaining a ballot to the person voting on it. What a row carries underneath
    # is the rest of that wording, where it outgrew the title (#numbered_pill).
    def send_pills(rows, body:)
      return send_buttons(rows, body: body) if ::Whatsapp.buttons?(rows.size)

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
        button_label: ::Whatsapp.copy("whatsapp.bot.buttons.choose", locale: locale),
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
      options.map do |option|
        answer_pill(option, ::Whatsapp::AssistantActions.truncated(marked(option, option.title)))
      end
    end

    # The same pills with the number the message prints beside each option in front
    # of the wording, for a question whose choices arrive behind the picker. It is
    # what a citizen reads the row back by against the options printed above.
    #
    # Always rows of a list — #offer_choices only numbers the options that do not
    # fit as buttons — so the wording is split over the row's two lines rather than
    # cut to a button's twenty characters (Whatsapp::ListRowText): the rest of the
    # option carries on underneath, where two options opening with the same words
    # used to arrive as two rows reading alike but for their numbers.
    def numbered_pills(options)
      numbered(options).filter_map { |number, option| numbered_pill(number, option) }
    end

    # A scale's first and last step carry what that end means on the line underneath,
    # where a row reading "1" would otherwise be all the citizen has to go on.
    def numbered_pill(number, option)
      lines = ::Whatsapp::ListRowText.call(
        name: marked(option, option_label(number, option)), notes: [scale_end_note(option)]
      )

      return if lines.blank?

      answer_pill(option, lines[:title]).merge(description: lines[:description]).compact
    end

    # The mark in front of a chosen option's label, where a pill's label starts, so a
    # cut label still shows it.
    def marked(option, label)
      return label if !chosen?(option)

      "#{CHOSEN_MARK} #{label}"
    end

    # Whether the option's own wording is already the number standing in front of it.
    # A rating scale is kept as choices titled "1" to "5", and portals write plain
    # questions the same way, so without this the pair arrives as "1. 1".
    def self_numbered?(number, option)
      option.title.to_s.strip == number.to_s
    end

    def answer_pill(option, title)
      { id: ::Whatsapp::FlowActions.id_for(action: :poll_answer, param: option.id), title: title }
    end

    # The pairing itself, in one place because both sides of it are built separately —
    # the pills here and the lines in the message body — and a number that means one
    # option on a button and another in the text is worse than no number at all.
    def numbered(options)
      options.each_with_index.map { |option, index| [index + 1, option] }
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
        title: ::Whatsapp.copy("whatsapp.bot.buttons.poll_done", locale: locale)
      }
    end

    def skip_pill
      {
        id: ::Whatsapp::FlowActions.id_for(action: :poll_skip, param: question.id),
        title: ::Whatsapp.copy("whatsapp.bot.buttons.poll_skip", locale: locale)
      }
    end

    # The poll's name above the question because a card or a list may have put the
    # citizen here several messages ago, and a question with no ballot named over it
    # reads as the bot asking something of its own. The count under it because a
    # ballot asked one message at a time otherwise gives no sense of its own length —
    # on the page that is what the progress bar is for.
    def body(printed_options)
      progress, choices, hint = translated(
        progress_text, choices_text, options_hint_text(printed_options)
      )

      [
        "*#{question.poll.name}*", progress, question.title, scale_text,
        options_text(printed_options), choices, hint
      ].compact_blank.join("\n\n")
    end

    # The options as a numbered column, in the order the rows offer them and at their
    # full length. Out of the translation call, like the question's own title and the
    # scale's labels: an option answered against a paraphrase of it is not the option
    # that was published.
    def options_text(options)
      return if options.empty?

      numbered(options).map { |number, option| option_line(number, option) }.join("\n")
    end

    # The mark after the wording rather than in front of it, so the numbers stay one
    # column down the left of the message.
    def option_line(number, option)
      return "#{option_label(number, option)} #{CHOSEN_MARK}" if chosen?(option)

      option_label(number, option)
    end

    def option_label(number, option)
      return number.to_s if self_numbered?(number, option)

      "#{number}. #{option.title}"
    end

    # Where the answer is given, which a citizen who has just read the options in the
    # text has no other reason to look for — the picker is a button saying nothing
    # about what it opens. Nothing where the options were not printed: the buttons
    # under a short question are the answer and say so themselves. Nothing for a
    # multiple question either, whose own line (#choices_text) says it already: two
    # lines telling the citizen to choose below read as one said twice.
    def options_hint_text(options)
      return if options.empty?
      return if question.multiple?

      ::Whatsapp.copy("whatsapp.bot.poll.options_hint")
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
    #
    # A scale the portal left unlabelled still gets its ends said, as the lowest and
    # the highest step: a column of bare numbers does not say which end is which.
    def scale_text
      return if !question.rating_scale?

      if portal_scale_labels.all?(&:present?)
        minimum, maximum = portal_scale_labels

        return ::Whatsapp.copy(
          "whatsapp.bot.poll.scale", minimum: minimum, maximum: maximum, locale: locale
        )
      end

      lowest = titled_options.first
      highest = titled_options.last

      return if lowest.blank? || lowest == highest

      ::Whatsapp.copy(
        "whatsapp.bot.poll.scale_steps",
        lowest: lowest.title, highest: highest.title, locale: locale
      )
    end

    # What one end of a scale means, for the row of its first or its last step —
    # the portal's label, or the bot's plain word for that end where it set none.
    def scale_end_note(option)
      return if !question.rating_scale?
      return if titled_options.size < 2

      if option.id == titled_options.first.id
        portal_scale_labels.first.presence ||
          ::Whatsapp.copy("whatsapp.bot.poll.scale_lowest", locale: locale)
      elsif option.id == titled_options.last.id
        portal_scale_labels.last.presence ||
          ::Whatsapp.copy("whatsapp.bot.poll.scale_highest", locale: locale)
      end
    end

    def portal_scale_labels
      @portal_scale_labels ||= [
        question.votation_type&.min_rating_scale_label,
        question.votation_type&.max_rating_scale_label
      ]
    end

    def text_body
      progress, prompt = translated(progress_text, ::Whatsapp.copy("whatsapp.bot.poll.open_prompt"))

      ["*#{question.poll.name}*", progress, question.title, prompt].compact_blank.join("\n\n")
    end

    # The choice under the question rather than beside the numbers: a weight pill
    # carries a digit and nothing else, so the only place the citizen can read what
    # they are weighting is the message above them. At full length, and out of the
    # translation call, because it is the poll's own wording like the question's.
    def weight_body(choice)
      progress, prompt = translated(progress_text, weight_prompt_text(choice))

      [
        "*#{question.poll.name}*", progress, question.title,
        weighted_choices_text(choice), prompt
      ].compact_blank.join("\n\n")
    end

    # Every choice the question holds, with the one being weighted now in bold. A
    # weighted question arrives one choice at a time, so a citizen asked for the first
    # number has no way to know how many more are coming or how far the budget has to
    # stretch — and a weight is spent the moment it is tapped.
    #
    # Not numbered, unlike the options of a question answered by tapping one: the
    # pills here are numbers themselves, and a numbered list above them reads as the
    # digits to tap.
    def weighted_choices_text(choice)
      all_options.map do |option|
        next "• *#{option.title}*" if option.id == choice.id

        "• #{option.title}"
      end.join("\n")
    end

    def weight_prompt_text(choice)
      ::Whatsapp.copy(
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
      return ::Whatsapp.copy("whatsapp.bot.poll.location_prompt") if question.max_map_points < 2

      ::Whatsapp.copy(
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

      ::Whatsapp.copy("whatsapp.bot.poll.progress", number: @position.number, total: @position.total)
    end

    # How many choices the question allows, which a citizen looking at a list of
    # pills has no other way to know. Poll::Question#max_votes falls back to the
    # number of options where the portal set no maximum, so the sentence is true
    # either way.
    #
    # Once something is chosen it also says how a choice is taken back, and at the
    # maximum that nothing more can be added — the question no longer moves on by
    # itself there, so this line is the confirmation that the last choice counted.
    def choices_text
      return if !question.multiple?

      chosen = chosen_titles.size
      maximum = question.max_votes

      return ::Whatsapp.copy("whatsapp.bot.poll.choices", maximum: maximum) if chosen.zero?

      if chosen >= maximum
        return ::Whatsapp.copy("whatsapp.bot.poll.maximum_selected", maximum: maximum)
      end

      ::Whatsapp.copy("whatsapp.bot.poll.choices_selected", chosen: chosen, maximum: maximum)
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
