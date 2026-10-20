class Whatsapp::Polls::ListProjektPollsService < ApplicationService
  # The open votes of one projekt as a list to pick from, sent on the tap of the
  # projekt card's last row. That row used to be handed to the assistant as a tap
  # on "show_more, polls", and which projekt's votes it meant was the model's to
  # remember from the card's result: on staging it answered twice with one of the
  # ballots instead of the list. The row names its projekt now, so the list is
  # composed here and can only be that projekt's.
  #
  # Ordered and marked the way the assistant's own list of open votes is
  # (Whatsapp::BallotParticipation.still_owed_first), so the same votes read alike
  # whichever of the two sent them. Each row starts its vote through the same
  # `phase_open` the card's rows carry, which begins the ballot in the chat where
  # it can be carried to the end and sends its address where it cannot.
  #
  # Answers false where the projekt has no open vote left, and the caller hands
  # the tap to the assistant, which says so better than a fixed line would.
  def initialize(account:, projekt:, from: 0)
    @account = account
    @projekt = projekt
    @from = from
  end

  def call
    polls = ::Whatsapp::OpenPollsQuery.new(projekt: @projekt).all

    return false if polls.empty?

    states = ::Whatsapp::BallotParticipation.states_by_poll_id(
      polls: polls, user: @account.user
    )
    ordered = ::Whatsapp::BallotParticipation.still_owed_first(polls, states)
    from = page_start(ordered)
    page = ::Whatsapp::ListWindow.page(ordered, from: from)
    copy = translated_copy(page)
    rows = page.each_with_index.map { |poll, index| poll_row(poll, states, copy, index) }

    ::Whatsapp::Send.list(
      account: @account,
      body: copy[:body],
      button_label: copy[:button_label],
      rows: [*rows.compact.uniq { |row| row[:id] }, more_row(ordered, from, page, copy)].compact
    )

    true
  end

  private

    # A pill tapped long after it was sent may point past the end of a list that
    # has shrunk since, and the first page is the answer the citizen can read.
    def page_start(ordered)
      from = ::Whatsapp::ListWindow.offset(@from)

      return 0 if from >= ordered.size

      from
    end

    def poll_row(poll, states, copy, index)
      answered = states[poll.id] == ::Whatsapp::BallotParticipation::ANSWERED
      lines = ::Whatsapp::ListRowText.call(
        name: answered ? voted_title(poll) : poll.name,
        notes: [answered ? copy[:voted] : nil, copy[:dates][index]]
      )

      return if lines.blank?

      {
        id: ::Whatsapp::FlowActions.id_for(action: :phase_open, param: poll.projekt_phase_id),
        **lines
      }
    end

    # The card's own mark for a vote the citizen has answered in full, so a row
    # reads the same on the card and here.
    def voted_title(poll)
      ::Whatsapp::ProjektCardActions.voted_title(poll.name) || poll.name
    end

    def more_row(ordered, from, page, copy)
      next_from = from + page.size

      return if next_from >= ordered.size

      {
        id: ::Whatsapp::FlowActions.id_for(
          action: ::Whatsapp::FlowActions::DIRECT_VOTES_ACTION,
          param: ::Whatsapp::FlowActions.page_param(record_id: @projekt.id, from: next_from)
        ),
        title: copy[:show_more]
      }
    end

    # Every fixed line of the message in one translation call, the closing dates
    # included, the way the list of a phase's contributions is worded. The poll
    # names are not among them: a name is what the portal published the ballot
    # under.
    def translated_copy(page)
      fixed = [
        ::Whatsapp.copy(
          "whatsapp.bot.poll.projekt_list", projekt: ::Whatsapp::ProjektLink.title(@projekt)
        ),
        ::Whatsapp.copy("whatsapp.bot.buttons.choose"),
        ::Whatsapp.copy("whatsapp.bot.buttons.show_more"),
        voted_word(page.first)
      ]
      dates = page.map { |poll| ::Whatsapp::DatePhrase.absolute(poll.ends_at) }
      lines = ::Whatsapp::AiAssistant::BotCopyService.call(
        account: @account, lines: fixed + dates
      )

      {
        body: lines[0],
        button_label: lines[1],
        show_more: lines[2],
        voted: lines[3],
        dates: lines.drop(fixed.size)
      }
    end

    # The word the card puts under a vote the citizen has answered, read for the
    # phase type the way the card reads it. Every row of this list is a vote, so
    # the first one's phase answers for all of them.
    def voted_word(poll)
      ::Whatsapp::ProjektCardActions.scoped_label(
        ::Whatsapp::ProjektCardActions::VOTED_LABEL_SCOPE, poll.projekt_phase
      )
    end
end
