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
              "projekts at once is send_list, not a card each. The card carries its own button " \
              "for taking part where its phase is open, so do not offer that again yourself."

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
    def send_card(projekt, summary)
      ::Whatsapp::Send.buttons_with_picture(
        account: account,
        body: card_body(projekt, summary),
        buttons: card_buttons(projekt),
        image_url: ::Whatsapp::ProjektCard.image_url(projekt)
      )
    end

    # The one pill the card offers, and only where a phase is actually open —
    # offering a submission into a closed projekt is the one thing the ticket's rule
    # about reachability forbids. Send reserves the last slot for the main menu, so a
    # projekt with an open phase arrives with two buttons and one without with the
    # way back alone.
    #
    # Telling more about the projekt used to be a pill here as well. It sat between
    # the citizen picking a projekt and doing anything with it, and what it delivered
    # was the card's own three facts worded differently — so the detail is in the
    # summary now and the step is gone.
    #
    # Labelled from the locale copy rather than the record: the title is already the
    # first line of the card, so a pill repeating it says nothing, and the projekt's
    # own name is routinely longer than a label holds.
    def card_buttons(projekt)
      open_phase = ::Whatsapp::EligiblePhasesQuery.new(projekt: projekt).call.first

      return [] if open_phase.blank?

      [pill(:idea_start, open_phase.id, "take_part")]
    end

    def pill(action, param, label)
      {
        id: ::Whatsapp::FlowActions.id_for(action: action, param: param),
        title: I18n.t("whatsapp.bot.buttons.#{label}")
      }
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
