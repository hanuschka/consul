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
              "one specific projekt or are asked to tell them about one, instead of writing the " \
              "address into your reply. Identified by name rather than by id, so it reaches " \
              "finished projekts too. Write the summary from what describe_projekt returned, in " \
              "the citizen's language, and do not repeat it or the link in a reply afterwards. " \
              "The summary itself says what the projekt is about — never send the citizen to " \
              "the link to find that out. Naming several projekts at once is send_list, not a " \
              "card each. The card carries its own buttons — telling more about the projekt " \
              "and, where its phase is open, taking part in it — so do not offer those again " \
              "yourself. Never call it in answer to a tapped view_projekt button: that tap asks " \
              "for more than the card, which is describe_projekt and a plain reply."

  params do
    string :projekt_name, description: "The projekt name as the citizen wrote it"
    string :summary,
      description: "Two or three sentences saying what the projekt is about, in the citizen's " \
                   "language, from what a tool in this conversation returned."
  end

  def execute(projekt_name:, summary:)
    projekt = readable_projekt(projekt_name)

    return unknown_projekt_error(projekt_name) if projekt.blank?
    return card_repeat_error(projekt) if answers_own_tap?(projekt)

    send_card(projekt, summary)

    # Halts like every tool that sends its own message: the card already carries
    # the title, the summary, the picture and the link, so a further completion
    # would pay for a sentence that may only repeat them.
    halt("Sent the card for #{projekt_title(projekt)}, carrying the title, your summary, the " \
         "picture and the link.")
  end

  private

    # The card must never answer with itself. The inbound side records which pill
    # the citizen tapped before the model is asked, so a card sent in reply to the
    # card's own "view projekt" pill is refused here rather than left to the prompt —
    # a sentence in a description is something a model can talk itself past, and
    # what is on the other side of this one is the loop the ticket describes.
    def answers_own_tap?(projekt)
      tap = conversation.inbound_tap.to_h

      tap["action"].to_s == "view_projekt" && tap["param"].to_s == projekt.id.to_s
    end

    def card_repeat_error(projekt)
      ::Whatsapp::AiAssistant::DecisionLog.record(
        event: :card_repeat_refused, conversation: conversation, projekt_id: projekt.id
      )

      {
        error: "The citizen just tapped the view_projekt button on the card for " \
               "#{projekt_title(projekt)}, so sending that card again would only repeat it. " \
               "Call describe_projekt and tell them in your own words what the projekt is " \
               "about, which phases are open and until when, in a plain reply that stays open " \
               "for follow-up questions."
      }
    end

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

    # Two at most, because Send reserves the third for the main menu, and the phase
    # pill only where a phase is actually open — offering a submission into a closed
    # projekt is the one thing the ticket's rule about reachability forbids.
    #
    # The "view projekt" pill only where there is more to tell than the card already
    # carries: on a thin projekt with no phases it would deliver the card again, and
    # it would take a button slot from the pills that do something.
    #
    # Labelled from the locale copy rather than the record: the title is already the
    # first line of the card, so a pill repeating it says nothing, and the projekt's
    # own name is routinely longer than a label holds.
    def card_buttons(projekt)
      open_phase = ::Whatsapp::EligiblePhasesQuery.new(projekt: projekt).call.first
      pills = []

      if ::Whatsapp::ProjektCard.tells_more?(projekt)
        pills << pill(:view_projekt, projekt.id, "view_projekt")
      end

      if open_phase.present?
        pills << pill(:idea_start, open_phase.id, "take_part")
      end

      pills
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
