class Ai::Tools::WhatsappAiAssistant::SendProjektCard < Ai::Tools::WhatsappAiAssistant::BaseTool
  # One projekt as a card: the title as the portal writes it, the picture, the
  # link, and the summary the model wrote. The picture and the title come from the
  # record because they are facts about it; the summary is a sentence, so it is the
  # model's — which also means it is written with the citizen's actual question in
  # view, where a detached summariser never had one.
  BODY_MAX_LENGTH = 1024
  SEPARATOR = "\n\n".freeze

  # What the summary is asked to stay within, well inside what the body leaves
  # it. The cut in #card_body is the backstop and not the budget: a projekt
  # running nine votes arrived as nine sentences alike and broke off at
  # "31. Dezem…", because the model had been asked for a sentence per phase and
  # nothing about length.
  SUMMARY_TARGET_LENGTH = 600

  # Where a sentence ends, for the backstop cut: a stop, a question or an
  # exclamation mark followed by a space or the end. Not after a digit, which
  # in German is a date — "bis 31. Dezember" is one sentence and not two.
  SENTENCE_END = /(?<!\d)[.!?](?=\s|\z)/

  description "Sends the citizen one projekt as a card — its title, its picture, the summary you " \
              "write and its link, in a message of its own. Call it whenever you point them at " \
              "one specific projekt, are asked to tell them about one, or they pick one from a " \
              "list, instead of writing the address into your reply. Identified by name rather " \
              "than by id, so it reaches finished projekts too. The card is the whole answer to " \
              "a projekt choice, so the summary carries the detail right away: what the projekt " \
              "collects, what the citizen can do in it now, and until when — short, at most " \
              "about #{SUMMARY_TARGET_LENGTH} characters. Write it from what " \
              "describe_projekt returned, in the citizen's language, and do not repeat it " \
              "or the link in a reply afterwards. The summary itself says what the projekt is " \
              "about — never send the citizen to the link to find that out. Naming several " \
              "projekts at once is send_list, not a card each. The card carries a button of its " \
              "own for each of the projekt's open phases, worded as the action it starts, and " \
              "one that opens what has already been contributed — so never offer taking part, a " \
              "phase to choose from or the existing contributions yourself alongside it."

  params do
    string :projekt_name, description: "The projekt name as the citizen wrote it"
    string :summary,
      description: "What the projekt is about, then what can be done in it now and until when. " \
                   "Phases of one kind that close on the same day are one sentence — \"nine " \
                   "votes are running until 31 December 2026\" — never a sentence each; name a " \
                   "phase on its own only where its kind or its closing date sets it apart. " \
                   "The card's buttons list the phases, so the summary does not have to. Say " \
                   "that a phase is running where its running field says so, even where it " \
                   "takes no written contribution, and say which of them the chat can take a " \
                   "contribution into. At most about #{SUMMARY_TARGET_LENGTH} characters, in the " \
                   "citizen's language, from what describe_projekt returned in this conversation."
  end

  def execute(projekt_name:, summary:)
    refusal = refuse_before_preview

    return refusal if refusal.present?

    projekt = readable_projekt(projekt_name)

    return unknown_projekt_error(projekt_name) if projekt.blank?

    actions = ::Whatsapp::ProjektCardActions.call(projekt, user: conversation.user)

    send_card(projekt, summary, actions)

    entered = enter_single_open_phase(projekt)

    note_typing_hint_offered!

    # Halts like every tool that sends its own message: the card already carries
    # the title, the summary, the picture and the link, so a further completion
    # would pay for a sentence that may only repeat them.
    halt(
      "Sent the card for #{projekt_title(projekt)}, carrying the title, your summary, the " \
      "picture and the link.#{entered_note(entered)}#{more_votes_note(projekt, actions)}"
    )
  end

  private

    # Picking a projekt is how a citizen says what they want to talk about, and
    # where the projekt has exactly one thing the chat can take a contribution
    # into, it is also how they say which phase they mean. Left unset, the
    # conversation reads "no active phase" and the contribution they write next is
    # sent to the topic search instead of into a draft — answered, in the case this
    # comes from, with no projekt being about it.
    #
    # Two or more open phases is a real question and the card's own pills ask it,
    # one per phase. None is nothing to enter.
    #
    # Only where there is nothing to lose. start_draft! replaces the context, so a
    # citizen part-way through a submission or a ballot would have it taken from
    # under them by a card they asked to see.
    def enter_single_open_phase(projekt)
      return if conversation.unsaved_work?
      return if conversation.active_poll_id.present?

      open_phases = ::Whatsapp::EligiblePhasesQuery.uncapped(projekt: projekt)

      return if open_phases.size != 1

      conversation.start_draft!(open_phases.first)

      open_phases.first
    end

    # Said to the model because the card said nothing about it to the citizen: the
    # phase is open underneath, and what the model must not do now is search for a
    # projekt when their next message is the contribution itself.
    def entered_note(projekt_phase)
      return "" if projekt_phase.blank?

      " Their submission to *#{projekt_phase.title}* is open, so whatever they write next is " \
        "their contribution — call draft_proposal with it rather than searching for a projekt."
    end

    # Said to the model because the tap on the card's last row reaches it as
    # "show_more, polls" and nothing else: which projekt's votes that means is
    # only written down here, in the result it will read the tap against.
    def more_votes_note(projekt, actions)
      more_votes = ::Whatsapp::ProjektCardActions.more_votes?(actions)

      return "" if !more_votes

      " The card had no row for every vote, so its last row opens them all: when the " \
        "citizen taps it (action show_more, id polls), call list_open_polls with the " \
        "projekt name \"#{projekt_title(projekt)}\" and send its votes for them to pick " \
        "from. The tap asks to see the votes, not to vote: start none they have not picked."
    end

    # Buttons rather than a caption on its own, which is what this sent before: a
    # card is the one message where the next step is never in doubt — the citizen is
    # looking at one projekt — and it was the only tappable-looking thing in the chat
    # that could not be tapped.
    #
    # Routed through buttons_with_picture rather than image, so the picture and the
    # pills arrive on one message and the ladder that gives the picture up when
    # WhatsApp will not take it is the transport's rather than this tool's.
    #
    # Which actions the card offers is Whatsapp::ProjektCardActions': one per open
    # phase, worded as the action itself. There used to be one pill here for all of
    # them, which only opened a further step where the citizen picked which phase they
    # meant — a question the card had already answered by being about this projekt.
    #
    # The citizen goes with the projekt because the wording of a phase's pill depends on
    # what they have already done in it: a vote they took part in is labelled as such
    # here rather than only after they tap it.
    #
    # Telling more about the projekt used to be a pill as well. It sat between the
    # citizen picking a projekt and doing anything with it, and what it delivered was
    # the card's own three facts worded differently — so the detail is in the summary
    # now and the step is gone.
    def send_card(projekt, summary, actions)
      if ::Whatsapp::ProjektCardActions.list_required?(actions)
        return send_action_list(projekt, summary, actions)
      end

      # A projekt whose open phases are all of a type with nothing to do in them — a
      # newsfeed, a milestone — has no action to offer, and that is a dead end: the
      # card is worth reading and there is nowhere on from it. The way back stands in
      # for the actions, and it also keeps the message sendable, an interactive one
      # carrying no buttons at all being the one thing WhatsApp refuses outright.
      ::Whatsapp::Send.buttons_with_picture(
        account: account,
        body: card_body(projekt, summary),
        buttons: actions.presence || [::Whatsapp::Send.main_menu_pill(account)],
        image_url: ::Whatsapp::ProjektCard.image_url(projekt)
      )
    end

    # The card becomes a list where reply buttons cannot carry the actions — more than
    # three of them, or two that would read alike, which is Whatsapp::ProjektCardActions'
    # call. The picture goes as a message of its own ahead
    # of it rather than being dropped: a list message takes no header at all, and the
    # picture is the half of a card a citizen recognises the projekt by. It is sent
    # first so the two arrive in the order they would have been read in, and its
    # absence costs nothing — Whatsapp::Send.picture answers nil for a projekt with no
    # showable one and the list follows either way.
    def send_action_list(projekt, summary, actions)
      ::Whatsapp::Send.picture(
        account: account, image_url: ::Whatsapp::ProjektCard.image_url(projekt)
      )

      ::Whatsapp::Send.list(
        account: account,
        body: card_body(projekt, summary),
        button_label: ::Whatsapp.copy("whatsapp.bot.buttons.choose"),
        rows: actions
      )
    end

    # The summary is what gives when the budget runs out, never the link: a projekt
    # the bot informs about always arrives with somewhere to read more.
    def card_body(projekt, summary)
      title_line = "*#{projekt_title(projekt)}*"
      url = projekt_url(projekt)
      budget = BODY_MAX_LENGTH - title_line.length - url.to_s.length - (SEPARATOR.length * 2)

      [title_line, fitted_summary(summary.to_s.squish, budget), url]
        .compact_blank
        .join(SEPARATOR)
    end

    # Cut after the last whole sentence that fits, or failing one at the last
    # whole word. A card whose text broke off at "31. Dezem…" read as a message
    # damaged in transit rather than as one that had been shortened.
    def fitted_summary(text, budget)
      return text if text.length <= budget

      sentence_end = text.rindex(SENTENCE_END, budget - 1)

      if sentence_end.present?
        text.first(sentence_end + 1)
      else
        text.truncate(budget, separator: " ", omission: "…")
      end
    end
end
