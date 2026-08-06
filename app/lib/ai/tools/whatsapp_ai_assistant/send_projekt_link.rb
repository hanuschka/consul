class Ai::Tools::WhatsappAiAssistant::SendProjektLink < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Sends the citizen a tappable button opening the web page of the projekt behind an " \
              "open participation phase. Use it when they want to read more, see other people's " \
              "contributions, or do something the chat cannot do. This sends the message itself " \
              "— do not write one as well."

  params do
    integer :projekt_phase_id, description: "Id of an open participation phase"
    string :body, description: "One or two sentences introducing the link, in the citizen's language"
  end

  def execute(projekt_phase_id:, body:)
    projekt_phase = eligible_phase(projekt_phase_id)

    return unknown_phase_error if projekt_phase.blank?

    deliver(body, projekt_url(projekt_phase.projekt))

    halt("Sent the citizen a link button to projekt phase #{projekt_phase.id}.")
  end

  private

    # A button WhatsApp refuses for any reason falls back to the plain link
    # rather than to silence, the same way the linking invitation does.
    def deliver(body, url)
      message = ::Whatsapp::Outbound.cta_url(
        account: account,
        body: body,
        button_label: I18n.t("whatsapp.bot.buttons.open_projekt"),
        url: url
      )

      return message if message&.status == "sent"

      ::Whatsapp::Outbound.text(account: account, body: "#{body}\n\n#{url}")
    end
end
