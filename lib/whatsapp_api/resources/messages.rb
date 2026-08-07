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
    send_sectioned_list(to: to, body: body, button_label: button_label, sections: [{ rows: rows }])
  end

  # WhatsApp counts rows across all sections against the same ten-row limit, so
  # grouping buys readability, never room.
  def send_sectioned_list(to:, body:, button_label:, sections:)
    @client.post(
      BASE_PATH,
      body: envelope(to).merge(
        type: "interactive",
        interactive: {
          type: "list",
          body: { text: body },
          action: {
            button: button_label.to_s.truncate(MAX_BUTTON_TITLE_LENGTH),
            sections: list_sections(sections)
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

    # The row budget is spent across the sections in order, so an over-long menu
    # loses its last rows rather than a slice out of every group. Dropping any
    # is logged: silently short lists read as "that is all there is".
    def list_sections(sections)
      remaining = MAX_LIST_ROWS

      kept = sections.filter_map do |section|
        rows = Array(section[:rows]).first(remaining)
        remaining -= rows.size

        next if rows.empty?

        { title: section[:title].to_s.truncate(MAX_ROW_TITLE_LENGTH).presence, rows: list_rows(rows) }
          .compact
      end

      log_dropped_rows(sections)

      kept
    end

    def log_dropped_rows(sections)
      total = sections.sum { |section| Array(section[:rows]).size }

      return if total <= MAX_LIST_ROWS

      Rails.logger.warn(
        "[Whatsapp] list had #{total} rows, #{total - MAX_LIST_ROWS} dropped past the limit"
      )
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
