class Whatsapp::Polls::OfferBallotService < ApplicationService
  # A voting phase's ballot begun in the chat, when the poll behind it is one a chat
  # can carry to the end. A false is the caller's signal to fall back to the link, which
  # is what every poll this cannot ask gets — and the link now opens the ballot itself
  # rather than the projekt page that lists it.
  #
  # Everything else says which of four things went out, because they are four
  # different things for a caller to say afterwards and one truthy value had them
  # reported as the first: the ballot's first question
  # (Whatsapp::Polls::AdvanceBallotService::ASKED), a ballot answered to its end in this
  # chat just now (COMPLETED), a vote this citizen took part in some time before and
  # cannot take part in again (ALREADY_VOTED), or the login link for a number with no
  # account behind it yet (LOGIN_OFFERED).
  #
  # The fallback is the whole design. A poll is checked before a word of it is sent
  # — Whatsapp::VotableBallotQuery decides, across every question it holds — so a
  # citizen who is asked a question here can always finish here, and one whose poll
  # holds a rating scale, a weighted vote or a map point is sent to the page where
  # all of it is legible. Beginning in the chat and handing over half-way would
  # leave the answers already given recorded and the rest not, which is a ballot
  # nobody meant to cast.
  #
  # The account rules are the portal's own, read through the phase: voting is not a
  # guest action anywhere, so a number with no account behind it is offered the
  # login link and the ballot is held until it comes back. Every other refusal —
  # too young, wrong district, verification still owed — goes to the portal, which
  # is where each of them can actually be resolved.
  LINKABLE_PROBLEMS = %i[not_logged_in guest_not_logged_in].freeze

  LOGIN_OFFERED = :login_offered

  # A ballot this citizen finished some time before now, which is a fourth thing that
  # can happen and used to be reported as the second. It reached AdvanceBallotService
  # like any other beginning, found nothing owed and closed the ballot off — so the
  # citizen was thanked for votes they had just cast, on a tap that cast none, and the
  # same tap could be made again and thanked again.
  #
  # Told apart here rather than there because the two are different before anything is
  # sent, not after: nothing is begun, no marker is written, and what the citizen is
  # owed is the fact that they took part earlier. AdvanceBallotService::COMPLETED keeps
  # the one meaning it can now only have, which is a ballot answered to its end in this
  # chat just now.
  ALREADY_VOTED = :already_voted

  def initialize(conversation:, projekt_phase:)
    @conversation = conversation
    @projekt_phase = projekt_phase
  end

  def call
    poll = ::Whatsapp::VotableBallotQuery.for(@projekt_phase)

    return false if poll.blank?

    problem = @projekt_phase.permission_problem(@conversation.user)

    return offer_login(poll) if LINKABLE_PROBLEMS.include?(problem)
    return false if problem.present?
    return confirm_participation(poll) if already_voted?(poll)

    begin_ballot(poll)
  end

  private

    # Whether there is anything left to ask, read from the recorded answers alone and
    # through the same reading the card's own mark is made from —
    # Whatsapp::BallotParticipation over Polls::BallotTraversalQuery — so a button saying
    # the citizen has voted and a tap saying they have not cannot both be right.
    #
    # The poll is passed rather than the phase because it is already resolved here: going
    # back through the phase would re-run the gate this method stands behind.
    #
    # Branching is answered by the walk itself, the way the ticket asks: taking part is
    # complete when the questions this citizen was actually led through are answered, not
    # when every question the poll holds is.
    def already_voted?(poll)
      ::Whatsapp::BallotParticipation.finished?(poll: poll, user: @conversation.user)
    end

    # Nothing is begun and no marker is written — a tap on a vote already answered
    # changes nothing, which is the whole of what it has to mean. The stored ballot is
    # deliberately left as it stands: the citizen may be half-way through a different
    # poll, and clearing it here would abandon that one for a tap that concerned another.
    #
    # Confirmed the way AdvanceBallotService confirms a completion, and for the same
    # reason: a fixed line with nothing under it to tap reads as the bot being finished
    # with the citizen, where what actually happened is that one thing they tried is
    # closed and everything else in the projekt is not.
    def confirm_participation(poll)
      confirm_earlier_vote(poll)

      ALREADY_VOTED
    end

    # Whichever route can reach the citizen, the way AdvanceBallotService#confirm_completion
    # picks one: the assistant carrying the conversation on, the turn this was reached from
    # reporting the outcome as its own result, or — where neither can — the fixed line.
    def confirm_earlier_vote(poll)
      return if carry_on(poll) != ::Whatsapp::AiAssistant::ContinueConversationService::UNAVAILABLE

      send_already_answered_line(poll)
    end

    def carry_on(poll)
      ::Whatsapp::AiAssistant::ContinueConversationService.call(
        conversation: @conversation,
        note: ::Whatsapp::CompletionNotes.ballot_already_answered(poll: poll)
      )
    end

    def send_already_answered_line(poll)
      ::Whatsapp::Send.locale_text(
        account: account,
        body: ::Whatsapp.copy("whatsapp.bot.poll.already_answered", poll: poll.name)
      )
    end

    # The poll is written down before the first question goes out, so a question the
    # citizen asks in the middle of the ballot can be answered and the ballot picked
    # up afterwards. Dropped again by AdvanceBallotService the moment there is
    # nothing left to ask.
    def begin_ballot(poll)
      @conversation.clear_pending_poll!
      @conversation.store_active_poll!(poll.id)

      # Its answer is this one's, ASKED and COMPLETED alike. COMPLETED is now only the
      # ballot whose last question was answered in this chat: one with nothing owed at
      # all never gets here, having been answered above. A ballot that could not be
      # carried on has cleared its own markers and left the link as the right thing to
      # send, and comes back as the false this passes on.
      ::Whatsapp::Polls::AdvanceBallotService.call(conversation: @conversation, poll: poll)
    end

    # The ballot the citizen was about to be given, held while they go and link. The
    # poll's id alone: it is re-resolved and re-checked when they come back, because
    # linking takes as long as it takes and a poll can close in between.
    def offer_login(poll)
      link_url = ::Whatsapp::Accounts::LinkTokenService.call(account: account)

      return false if link_url.blank?

      @conversation.store_pending_poll!(poll.id)

      prompt, button_label = ::Whatsapp::AiAssistant::BotCopyService.call(
        account: account,
        lines: [
          I18n.t(
            "whatsapp.bot.poll.login_prompt",
            poll: poll.name, privacy_url: ::Whatsapp::PortalLinks.privacy_url
          ),
          ::Whatsapp.copy("whatsapp.bot.buttons.login")
        ]
      )

      ::Whatsapp::Send.cta_url(
        account: account, body: prompt, button_label: button_label, url: link_url
      )

      LOGIN_OFFERED
    end

    def account
      @conversation.whatsapp_account
    end
end
