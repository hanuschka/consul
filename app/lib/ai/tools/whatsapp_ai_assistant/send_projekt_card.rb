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
              "Naming several projekts at once is send_list, not a card each."

  params do
    string :projekt_name, description: "The projekt name as the citizen wrote it"
    string :summary,
      description: "Two or three sentences saying what the projekt is about, in the citizen's " \
                   "language, from what a tool in this conversation returned."
  end

  def execute(projekt_name:, summary:)
    projekt = readable_projekt(projekt_name)

    return unknown_projekt_error(projekt_name) if projekt.blank?

    send_card(projekt, summary)

    # Halts like every tool that sends its own message: the card already carries
    # the title, the summary, the picture and the link, so a further completion
    # would pay for a sentence that may only repeat them.
    halt("Sent the card for #{projekt_title(projekt)}, carrying the title, your summary, the " \
         "picture and the link.")
  end

  private

    def send_card(projekt, summary)
      image_url = ::Whatsapp::ProjektCard.image_url(projekt)
      body = card_body(projekt, summary)

      return ::Whatsapp::Send.text(account: account, body: body) if image_url.blank?

      ::Whatsapp::Send.image(account: account, image_url: image_url, caption: body)
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
