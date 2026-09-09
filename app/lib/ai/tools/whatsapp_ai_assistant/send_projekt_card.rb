class Ai::Tools::WhatsappAiAssistant::SendProjektCard < Ai::Tools::WhatsappAiAssistant::BaseTool
  # One projekt as a card: the title as the portal writes it, the picture, the
  # link, and the summary the model wrote. The picture and the title come from the
  # record because they are facts about it; the summary is a sentence, so it is the
  # model's — which also means it is written with the citizen's actual question in
  # view, where a detached summariser never had one.
  BODY_MAX_LENGTH = 1024
  SEPARATOR = "\n\n".freeze

  description "Sends the citizen one projekt as a card — its title, its picture, the summary you " \
              "write and its link, in a message of its own. Call it whenever you point them at " \
              "one specific projekt, are asked to tell them about one, or they pick one from a " \
              "list, instead of writing the address into your reply. Identified by name rather " \
              "than by id, so it reaches finished projekts too. The card is the whole answer to " \
              "a projekt choice, so the summary carries the detail right away: what the projekt " \
              "collects, which phase takes contributions and how long it runs. Write it from " \
              "what describe_projekt returned, in the citizen's language, and do not repeat it " \
              "or the link in a reply afterwards. The summary itself says what the projekt is " \
              "about — never send the citizen to the link to find that out. Naming several " \
              "projekts at once is send_list, not a card each. The card carries a button of its " \
              "own for each of the projekt's open phases, worded as the action it starts, and " \
              "one that opens what has already been contributed — so never offer taking part, a " \
              "phase to choose from or the existing contributions yourself alongside it."

  params do
    string :projekt_name, description: "The projekt name as the citizen wrote it"
    string :summary,
      description: "Two to four sentences saying what the projekt is about, which phase takes " \
                   "contributions and until when, in the citizen's language, from what a tool " \
                   "in this conversation returned."
  end

  def execute(projekt_name:, summary:)
    projekt = readable_projekt(projekt_name)

    return unknown_projekt_error(projekt_name) if projekt.blank?

    send_card(projekt, summary)
    note_typing_hint_offered!

    # Halts like every tool that sends its own message: the card already carries
    # the title, the summary, the picture and the link, so a further completion
    # would pay for a sentence that may only repeat them.
    halt("Sent the card for #{projekt_title(projekt)}, carrying the title, your summary, the " \
         "picture and the link.")
  end

  private

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
    # Telling more about the projekt used to be a pill as well. It sat between the
    # citizen picking a projekt and doing anything with it, and what it delivered was
    # the card's own three facts worded differently — so the detail is in the summary
    # now and the step is gone.
    def send_card(projekt, summary)
      actions = ::Whatsapp::ProjektCardActions.call(projekt)

      return send_action_list(projekt, summary, actions) if actions.size > ::Whatsapp::MAX_BUTTONS

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

    # Past three actions the card has to become a list, because three is every reply
    # button a WhatsApp message holds. The picture goes as a message of its own ahead
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

      [title_line, summary.to_s.squish.truncate(budget), url].compact_blank.join(SEPARATOR)
    end
end
