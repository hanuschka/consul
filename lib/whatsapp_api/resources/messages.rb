class WhatsappApi::Resources::Messages
  BASE_PATH = "/messages".freeze
  MAX_BUTTONS = 3
  MAX_BUTTON_TITLE_LENGTH = 20

  def initialize(client)
    @client = client
  end

  def send_text(to:, body:)
    @client.post(
      BASE_PATH,
      body: envelope(to).merge(
        type: "text",
        text: { preview_url: true, body: body }
      )
    )
  end

  def send_template(to:, name:, language:, variables: [])
    @client.post(
      BASE_PATH,
      body: envelope(to).merge(
        type: "template",
        template: {
          name: name,
          language: { code: language },
          components: template_components(variables)
        }
      )
    )
  end

  def send_buttons(to:, body:, buttons:)
    @client.post(
      BASE_PATH,
      body: envelope(to).merge(
        type: "interactive",
        interactive: {
          type: "button",
          body: { text: body },
          action: { buttons: interactive_buttons(buttons) }
        }
      )
    )
  end

  private

    def envelope(to)
      {
        messaging_product: "whatsapp",
        recipient_type: "individual",
        to: to
      }
    end

    def template_components(variables)
      return [] if variables.blank?

      [
        {
          type: "body",
          parameters: variables.map { |variable| { type: "text", text: variable.to_s } }
        }
      ]
    end

    def interactive_buttons(buttons)
      buttons.first(MAX_BUTTONS).map do |button|
        {
          type: "reply",
          reply: {
            id: button[:id],
            title: button[:title].to_s.truncate(MAX_BUTTON_TITLE_LENGTH)
          }
        }
      end
    end
end
