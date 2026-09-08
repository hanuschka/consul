class Whatsapp::Polls::OfferQuestionService < ApplicationService
  # A voting phase's question put in front of the citizen as pills, when the poll
  # behind it is one a chat can carry to the end. Answers whether it did: a false
  # is the caller's signal to fall back to the phase's link, which is what every
  # poll this cannot ask gets.
  #
  # The fallback is the whole design. A poll is checked before a word of it is sent
  # — Whatsapp::VotableQuestionQuery decides — so a citizen who is asked a question
  # here can always finish here, and one whose poll has follow-ups, free text or
  # more options than a list holds is sent to the page where all of it is legible.
  # Beginning in the chat and handing over half-way would leave the answers already
  # given recorded and the rest not, which is a ballot nobody meant to cast.
  #
  # The account rules are the portal's own, read through the phase: voting is not a
  # guest action anywhere, so a number with no account behind it is offered the
  # login link and the question is held until it comes back. Every other refusal —
  # too young, wrong district, verification still owed — goes to the portal, which
  # is where each of them can actually be resolved.
  LINKABLE_PROBLEMS = %i[not_logged_in guest_not_logged_in].freeze

  def initialize(conversation:, projekt_phase:)
    @conversation = conversation
    @projekt_phase = projekt_phase
  end

  def call
    question = ::Whatsapp::VotableQuestionQuery.for(@projekt_phase)

    return false if question.blank?

    problem = @projekt_phase.permission_problem(@conversation.user)

    return ask(question) if problem.blank?
    return offer_login(question) if LINKABLE_PROBLEMS.include?(problem)

    false
  end

  # The question the citizen was about to be asked, held while they go and link. The
  # id alone: the poll is re-resolved and re-checked when they come back, because
  # linking takes as long as it takes and a poll can close in between.
  def offer_login(question)
    link_url = ::Whatsapp::Accounts::LinkTokenService.call(account: account)

    return false if link_url.blank?

    @conversation.store_pending_poll_question!(question.id)

    prompt, button_label = ::Whatsapp::AiAssistant::BotCopyService.call(
      account: account,
      lines: [
        I18n.t(
          "whatsapp.bot.poll.login_prompt",
          poll: question.poll.name, privacy_url: ::Whatsapp::PortalLinks.privacy_url
        ),
        I18n.t("whatsapp.bot.buttons.login")
      ]
    )

    ::Whatsapp::Send.cta_url(
      account: account, body: prompt, button_label: button_label, url: link_url
    )

    true
  end

  # Buttons while they fit and a list past that, the same fork the projekt card
  # makes. The options carry no descriptions: an option's own wording is the whole
  # of what it says, and a second line under it would be the bot explaining a ballot
  # to the person voting on it.
  def ask(question)
    options = pills(question)

    return false if options.size < ::Whatsapp::VotableQuestionQuery::MIN_OPTIONS

    @conversation.clear_pending_poll_question!

    return send_buttons(question, options) if options.size <= ::Whatsapp::MAX_BUTTONS

    send_list(question, options)
  end

  private

    def send_buttons(question, options)
      ::Whatsapp::Send.buttons(account: account, body: body(question), buttons: options)

      true
    end

    def send_list(question, options)
      ::Whatsapp::Send.list(
        account: account,
        body: body(question),
        button_label: I18n.t("whatsapp.bot.buttons.choose", locale: locale),
        rows: options
      )

      true
    end

    # The poll's name above the question because a card or a list may have put the
    # citizen here several messages ago, and a question with no ballot named over it
    # reads as the bot asking something of its own.
    #
    # Both are the portal's own words and are sent as written. Everything the bot
    # says goes into the citizen's language on its way out; what the portal wrote
    # does not, for the same reason a contribution's own text does not — a ballot
    # answered in a paraphrase of the question is not the ballot that was published.
    def body(question)
      ["*#{question.poll.name}*", question.title].compact_blank.join("\n\n")
    end

    # Labelled from the option, and resolved on the tap by its id rather than by its
    # label: WhatsApp allows twenty characters on a button title where an option may
    # run to a sentence, and Poll::Answer records the answer as text. Reading the
    # title off the record on the way back is what keeps a cut label from being
    # stored as the vote.
    def pills(question)
      ::Whatsapp::VotableQuestionQuery.options(question).filter_map do |option|
        title = ::Whatsapp::AssistantActions.truncated(option.title)

        next if title.blank?

        { id: ::Whatsapp::FlowActions.id_for(action: :poll_answer, param: option.id), title: title }
      end
    end

    def account
      @conversation.whatsapp_account
    end

    def locale
      ::Whatsapp.locale_for(account)
    end
end
