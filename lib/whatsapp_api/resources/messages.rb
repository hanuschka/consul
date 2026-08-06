class WhatsappApi::Resources::Messages
  BASE_PATH = "/messages".freeze
  MAX_BUTTONS = 3
  MAX_BUTTON_TITLE_LENGTH = 20
  MAX_LIST_ROWS = 10
  MAX_ROW_TITLE_LENGTH = 24
  MAX_ROW_DESCRIPTION_LENGTH = 72

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

  # A template whose approved shape is an image header, a text body and a URL
  # button — the projekt card. The button's variable is appended to the fixed
  # prefix baked into the template, so only the projekt id travels here.
  def send_card_template(to:, name:, language:, image_url:, variables:, button_variable:)
    @client.post(
      BASE_PATH,
      body: envelope(to).merge(
        type: "template",
        template: {
          name: name,
          language: { code: language },
          components: card_template_components(image_url, variables, button_variable)
        }
      )
    )
  end

  def send_list(to:, body:, button_label:, rows:)
    @client.post(
      BASE_PATH,
      body: envelope(to).merge(
        type: "interactive",
        interactive: {
          type: "list",
          body: { text: body },
          action: {
            button: button_label.to_s.truncate(MAX_BUTTON_TITLE_LENGTH),
            sections: [{ rows: list_rows(rows) }]
          }
        }
      )
    )
  end

  def send_cta_url(to:, body:, button_label:, url:)
    @client.post(
      BASE_PATH,
      body: envelope(to).merge(
        type: "interactive",
        interactive: {
          type: "cta_url",
          body: { text: body },
          action: {
            name: "cta_url",
            parameters: {
              display_text: button_label.to_s.truncate(MAX_BUTTON_TITLE_LENGTH),
              url: url
            }
          }
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

      [body_parameters(variables)]
    end

    # Component order is not significant to the API, but the button index is:
    # "0" is the first button declared on the approved template.
    def card_template_components(image_url, variables, button_variable)
      [
        { type: "header", parameters: [{ type: "image", image: { link: image_url } }] },
        body_parameters(variables),
        {
          type: "button",
          sub_type: "url",
          index: "0",
          parameters: [{ type: "text", text: button_variable.to_s }]
        }
      ]
    end

    def body_parameters(variables)
      {
        type: "body",
        parameters: Array(variables).map { |variable| { type: "text", text: variable.to_s } }
      }
    end

    def list_rows(rows)
      rows.first(MAX_LIST_ROWS).map do |row|
        {
          id: row[:id],
          title: row[:title].to_s.truncate(MAX_ROW_TITLE_LENGTH),
          description: row[:description].to_s.truncate(MAX_ROW_DESCRIPTION_LENGTH).presence
        }.compact
      end
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
