class Ai::Tools::WhatsappAiAssistant::SendLink < Ai::Tools::WhatsappAiAssistant::BaseTool
  # A URL button, which is the one thing about a link that plain text cannot do:
  # the citizen reads what they are about to open instead of a bare address. Falls
  # back to the address written out when WhatsApp will not take the button, because
  # a link that did not arrive is worse than one that arrived plainly.
  description "Sends the citizen a tappable link button — a sentence you write, and a labelled " \
              "button that opens the address. Use it for a login link, a verification page, one " \
              "contribution's page, or any single URL worth opening. The url must be one a tool " \
              "in this conversation returned; never write an address from memory or guess one. " \
              "For a projekt use send_projekt_card instead, which carries the picture and the " \
              "title with it. This sends the message itself — do not repeat the address in a " \
              "reply afterwards."

  params do
    string :body, description: "The sentence above the button, in the citizen's language."
    string :label,
      description: "What the button says, at most 20 characters (\"Seite öffnen\", \"Anmelden\")."
    string :url, description: "The address, exactly as a tool returned it."
  end

  def execute(body:, label:, url:)
    return blank_body_error if body.to_s.strip.blank?
    return invalid_url_error if !openable?(url)

    text = body.strip
    message = ::Whatsapp::Send.cta_url(
      account: account,
      body: text,
      button_label: ::Whatsapp::AssistantActions.truncated(label).presence ||
                    I18n.t("whatsapp.bot.buttons.open_page"),
      url: url
    )

    return halt("Sent the link button to #{url}.") if message&.status == "sent"

    ::Whatsapp::Send.text(account: account, body: "#{text}\n\n#{url}")

    halt("The link button was refused, so the address was sent written out instead.")
  end

  private

    # http or https only, and parseable. A model that reached for a scheme WhatsApp
    # cannot open would have the whole message refused, which reads to the citizen
    # as a bot that stopped answering.
    def openable?(url)
      parsed = URI.parse(url.to_s)

      parsed.is_a?(URI::HTTP) && parsed.host.present?
    rescue URI::InvalidURIError
      false
    end

    def blank_body_error
      { error: "The link needs a sentence above it saying what it opens." }
    end

    def invalid_url_error
      { error: "That is not a usable web address. Use one exactly as a tool returned it, or say " \
               "you have no link to give rather than guessing one." }
    end
end
