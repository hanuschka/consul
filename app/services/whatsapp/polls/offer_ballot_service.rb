class Whatsapp::Polls::OfferBallotService < ApplicationService
  # A voting phase's ballot begun in the chat, when the poll behind it is one a chat
  # can carry to the end. A false is the caller's signal to fall back to the link, which
  # is what every poll this cannot ask gets — and the link now opens the ballot itself
  # rather than the projekt page that lists it.
  #
  # Everything else says which of three things went out, because they are three
  # different things for a caller to say afterwards and one truthy value had them
  # reported as the first: the ballot's first question
  # (Whatsapp::Polls::AdvanceBallotService::ASKED), a ballot that had nothing left to
  # ask and was confirmed rather than begun (COMPLETED), or the login link for a number
  # with no account behind it yet (LOGIN_OFFERED).
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

  def initialize(conversation:, projekt_phase:)
    @conversation = conversation
    @projekt_phase = projekt_phase
  end

  def call
    poll = ::Whatsapp::VotableBallotQuery.for(@projekt_phase)

    return false if poll.blank?

    problem = @projekt_phase.permission_problem(@conversation.user)

    return begin_ballot(poll) if problem.blank?
    return offer_login(poll) if LINKABLE_PROBLEMS.include?(problem)

    false
  end

  private

    # The poll is written down before the first question goes out, so a question the
    # citizen asks in the middle of the ballot can be answered and the ballot picked
    # up afterwards. Dropped again by AdvanceBallotService the moment there is
    # nothing left to ask.
    def begin_ballot(poll)
      @conversation.clear_pending_poll!
      @conversation.store_active_poll!(poll.id)

      # Its answer is this one's, ASKED and COMPLETED alike: a ballot with nothing left
      # to ask is a citizen who has already voted on every question of it, which is a
      # different thing to report than a ballot that has just begun. A ballot that could
      # not be carried on has cleared its own markers and left the link as the right
      # thing to send, and comes back as the false this passes on.
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
          I18n.t("whatsapp.bot.buttons.login")
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
