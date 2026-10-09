class Ai::Tools::WhatsappAiAssistant::SendProjektCard < Ai::Tools::WhatsappAiAssistant::BaseTool
  requires_approval

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
              "projekts at once is send_list, not a card each. The card carries a row of its " \
              "own for each of the projekt's open phases, worded as the action it starts, one " \
              "that opens what has already been contributed and, where it has no room for " \
              "every vote, one that opens them all — so never offer taking part, a phase to " \
              "choose from, the existing contributions or the list of votes yourself alongside " \
              "it. Where the citizen asked to submit something before picking the projekt, the " \
              "card offers only the way to submit — and where the projekt takes a submission " \
              "in one phase only, no card is sent and their submission there is opened instead."

  parameters do
    string :projekt_name, description: "The projekt name as the citizen wrote it"
    string :summary,
      description: "What the projekt is about, then what can be done in it now and until when. " \
                   "Phases of one kind that close on the same day are one sentence — \"nine " \
                   "votes are running until 31 December 2026\" — never a sentence each; name a " \
                   "phase on its own only where its kind or its closing date sets it apart. " \
                   "The card's buttons list the phases, so the summary does not have to. Say " \
                   "that a phase is running where its running field says so, even where it " \
                   "takes no written contribution, and say which of them the chat can take a " \
                   "contribution into. Where the citizen asked to submit something and nothing " \
                   "can be submitted to this projekt in the chat, say so. At most about " \
                   "#{SUMMARY_TARGET_LENGTH} characters, in the citizen's language, from what " \
                   "describe_projekt returned in this conversation."
  end

  # Where the card gave way to the submission it would have offered
  # (#open_wished_submission), the conversation is waiting for the idea.
  def diagnostic_step
    return if !@submission_opened

    ::Whatsapp::Conversation::Step::AWAITING_IDEA
  end

  def execute(projekt_name:, summary:)
    refusal = refuse_before_preview

    return refusal if refusal.present?

    projekt = readable_projekt(projekt_name)

    return unknown_projekt_error(projekt_name) if projekt.blank?

    all_actions = ::Whatsapp::ProjektCardActions.call(projekt, user: conversation.user)
    submission_actions = wished_submission_actions(all_actions)

    if submission_actions.one?
      opened = open_wished_submission(submission_actions.first)

      return opened if opened.present?
    end

    actions = submission_actions.presence || all_actions

    send_card(projekt, summary, actions)

    conversation.clear_submission_wish!

    entered = enter_single_open_phase(projekt)

    note_typing_hint_offered!

    # Halts like every tool that sends its own message: the card already carries
    # the title, the summary, the picture and the link, so a further completion
    # would pay for a sentence that may only repeat them.
    halt(
      "Sent the card for #{projekt_title(projekt)}, carrying the title, your summary, the " \
      "picture and the link.#{submission_note(submission_actions)}#{entered_note(entered)}" \
      "#{more_votes_note(actions)}"
    )
  end

  private

    # The rows that start a submission, where the citizen asked to submit something
    # before they picked this projekt (Whatsapp::Conversation#submission_wished?) and
    # the projekt takes one in the chat. Empty otherwise, and the card is the whole
    # card: a projekt with nothing to submit to still has to be shown, and its summary
    # is where that is said.
    def wished_submission_actions(actions)
      return [] if !conversation.submission_wished?

      ::Whatsapp::ProjektCardActions.submission_entries(actions)
    end

    # The citizen asked to submit something and picked a projekt that takes it in
    # one phase only, so the card would have repeated the question they had just
    # answered: a single "Vorschlag erstellen" row under the "Vorschlag erstellen"
    # they tapped to get here. The submission opens instead and the model asks for
    # the idea. Opened through StartDraft so that the unsaved-work, permission and
    # consent refusals stay that tool's alone, and called the way the model calls
    # it, so the decision log records it as its own tool result.
    #
    # Without the citizen's words: they picked a projekt with them, and StartDraft
    # would park them as the idea held over an unsaved-work question.
    #
    # Nil for a phase the chat cannot take a submission into, which leaves the card
    # to be sent with the wish still standing. Otherwise the wish is cleared here
    # rather than left to start_draft!, which the unsaved-work refusal never
    # reaches: a wish still standing would cut down the next card the citizen asks
    # to see.
    def open_wished_submission(submission_action)
      projekt_phase_id = ::Whatsapp::FlowActions.parse(submission_action[:id])[:param]

      return if eligible_phase(projekt_phase_id).blank?

      conversation.clear_submission_wish!

      start_result =
        ::Ai::Tools::WhatsappAiAssistant::StartDraft
          .new(conversation: conversation, citizen_words: nil)
          .call(projekt_phase_id: projekt_phase_id)

      return start_result if !start_result[:started]

      @submission_opened = true

      start_result.merge(
        card_sent: false,
        hint: "No card was sent: the citizen had asked to submit something and this projekt " \
              "takes it in one phase only, so their submission there is open. Name the " \
              "projekt when you ask for their idea, and do not offer it or its phases again."
      )
    end

    def submission_note(submission_actions)
      return "" if submission_actions.blank?

      " The citizen had asked to submit something before picking this projekt, so the card " \
        "offers only the way to submit here."
    end

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

    # Said to the model so that it does not offer the same list again. The tap on the
    # row is answered without it: the row names its projekt, and the inbound side
    # sends that projekt's votes (Whatsapp::Polls::ListProjektPollsService).
    def more_votes_note(actions)
      more_votes = ::Whatsapp::ProjektCardActions.more_votes?(actions)

      return "" if !more_votes

      " The card had no row for every vote, so its last row opens the list of all of them."
    end

    # A list rather than a caption on its own, which is what this sent at first: a
    # card is the one message where the next step is never in doubt — the citizen is
    # looking at one projekt — and it was the only tappable-looking thing in the chat
    # that could not be tapped.
    #
    # Reply buttons under the picture where the card has three actions or fewer and
    # every title fits a button whole and apart from the others, a list behind
    # "Auswählen" otherwise (Whatsapp::ProjektCardActions#buttons). A reply button
    # carries a title and nothing else, while every row of a list has a second line
    # to tell it apart by, so the buttons are only for the cards that need no such
    # line: one tap to the action is what a small card is worth.
    #
    # Which actions the card offers is Whatsapp::ProjektCardActions': one per open
    # phase, worded as the action itself. There used to be one pill here for all of
    # them, which only opened a further step where the citizen picked which phase they
    # meant — a question the card had already answered by being about this projekt.
    #
    # The citizen goes with the projekt because the wording of a phase's row depends on
    # what they have already done in it: a vote they took part in is marked as such
    # here rather than only after they tap it.
    #
    # Telling more about the projekt used to be a pill as well. It sat between the
    # citizen picking a projekt and doing anything with it, and what it delivered was
    # the card's own three facts worded differently — so the detail is in the summary
    # now and the step is gone.
    def send_card(projekt, summary, actions)
      # A projekt whose open phases are all of a type with nothing to do in them — a
      # newsfeed, a milestone — has no action to offer, and that is a dead end: the
      # card is worth reading and there is nowhere on from it. The way back stands in
      # for the actions, and it also keeps the message sendable, an interactive one
      # carrying no options at all being the one thing WhatsApp refuses outright.
      if actions.blank?
        return send_button_card(projekt, summary, [::Whatsapp::Send.main_menu_pill(account)])
      end

      buttons = ::Whatsapp::ProjektCardActions.buttons(actions)

      return send_button_card(projekt, summary, buttons) if buttons.present?

      send_action_list(projekt, summary, actions)
    end

    # Routed through buttons_with_picture rather than image, so the picture and the
    # buttons arrive on one message and the ladder that gives the picture up when
    # WhatsApp will not take it is the transport's rather than this tool's.
    def send_button_card(projekt, summary, buttons)
      ::Whatsapp::Send.buttons_with_picture(
        account: account,
        body: card_body(projekt, summary),
        buttons: buttons,
        image_url: ::Whatsapp::ProjektCard.image_url(projekt)
      )
    end

    # The picture goes as a message of its own ahead of the list rather than being
    # dropped: a list message takes no header at all, and the picture is the half of
    # a card a citizen recognises the projekt by. It is sent first so the two arrive in
    # the order they would have been read in, and its absence costs nothing —
    # Whatsapp::Send.picture answers nil for a projekt with no showable one and the
    # list follows either way.
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
