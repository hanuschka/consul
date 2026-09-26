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

  # Not a message, despite the endpoint: it marks the inbound message read and
  # shows the "typing…" bubble until a reply is sent, or for 25 seconds — Meta
  # and 360dialog both take it on POST /messages, which is why it lives here.
  #
  # There is no way to show typing without the read receipt; `status: "read"` is
  # required, not incidental.
  def send_typing_indicator(message_id:)
    @client.post(
      BASE_PATH,
      body: {
        messaging_product: "whatsapp",
        status: "read",
        message_id: message_id,
        typing_indicator: { type: "text" }
      }
    )
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

  # A picture with its text underneath, for a card that carries no buttons —
  # an interactive message must have at least one, so the two shapes cannot be
  # the same call.
  def send_image(to:, image_url:, caption: nil)
    send_image_message(to: to, image: image_by_link(image_url), caption: caption)
  end

  # The same picture where it exists only on an unpublished record: uploaded to
  # WhatsApp first, so nothing about the send depends on Meta being able to reach
  # us. The button-header route already had this pair; a captioned picture needs
  # it for the same reason.
  def send_image_by_media_id(to:, media_id:, caption: nil)
    send_image_message(to: to, image: image_by_id(media_id), caption: caption)
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

  # A template whose approved shape is a body and one quick-reply button. The
  # payload is what the tap sends back to us, so it is the send that decides what
  # the button means — one approved template serves every phase.
  def send_reply_button_template(to:, name:, language:, payload:, variables: [])
    @client.post(
      BASE_PATH,
      body: envelope(to).merge(
        type: "template",
        template: {
          name: name,
          language: { code: language },
          components: template_components(variables) + [quick_reply_button_parameters(payload)]
        }
      )
    )
  end

  # The same shape with a URL button, whose variable is appended to the fixed
  # prefix baked into the template — the record's id, and nothing else, travels.
  def send_link_button_template(to:, name:, language:, button_variable:, variables: [])
    @client.post(
      BASE_PATH,
      body: envelope(to).merge(
        type: "template",
        template: {
          name: name,
          language: { code: language },
          components: template_components(variables) + [url_button_parameters(button_variable)]
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
            button: fitted_button_title(button_label, field: "list button"),
            sections: list_sections(sections)
          }
        }
      )
    )
  end

  # WhatsApp's own location picker: the citizen taps the button this message
  # carries and shares a position from the map on their phone, so nothing on our
  # side has to guess coordinates out of a description.
  #
  # It takes no reply buttons of its own — the picker is the only action — so the
  # choice that leads here has to be an ordinary button message before it.
  def send_location_request(to:, body:)
    @client.post(
      BASE_PATH,
      body: envelope(to).merge(
        type: "interactive",
        interactive: {
          type: "location_request_message",
          body: { text: body },
          action: { name: "send_location" }
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
              display_text: fitted_button_title(button_label, field: "link button"),
              url: url
            }
          }
        }
      )
    )
  end

  # The header is optional because it is the one part WhatsApp will reject the
  # whole message over: it fetches the picture itself, from us, while the send
  # is in flight. A caller that cannot vouch for the URL passes none and gets
  # the same message without it.
  def send_buttons(to:, body:, buttons:, header_image_url: nil)
    send_button_message(
      to: to, body: body, buttons: buttons, header_image: image_by_link(header_image_url)
    )
  end

  # The same message with a picture WhatsApp already holds, named by the id its
  # own upload returned. A separate method rather than a second optional
  # argument beside the URL: exactly one of the two can be right for a given
  # picture, and the name says which one the caller has.
  def send_buttons_with_media_header(to:, body:, buttons:, header_media_id:)
    send_button_message(
      to: to, body: body, buttons: buttons, header_image: image_by_id(header_media_id)
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

    def card_template_components(image_url, variables, button_variable)
      [
        { type: "header", parameters: [{ type: "image", image: { link: image_url }}] },
        body_parameters(variables),
        url_button_parameters(button_variable)
      ]
    end

    # Component order is not significant to the API, but the button index is:
    # "0" is the first button declared on the approved template.
    def url_button_parameters(button_variable)
      {
        type: "button",
        sub_type: "url",
        index: "0",
        parameters: [{ type: "text", text: button_variable.to_s }]
      }
    end

    # What the citizen's tap sends back, capped at what WhatsApp allows a payload.
    # Every payload here is a Whatsapp::FlowActions id, which is far shorter, so an
    # overrun would be a new id shape rather than content too long to send.
    def quick_reply_button_parameters(payload)
      {
        type: "button",
        sub_type: "quick_reply",
        index: "0",
        parameters: [{ type: "payload", payload: payload.to_s }]
      }
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

    # A button label is the one capped string that is written to fit: locale copy or
    # the model's own words, both chosen against the twenty characters WhatsApp
    # allows. So one that overruns is a mistake in the wording rather than content
    # too long to show, and it is reported — a row title or a description quoted from
    # the portal overruns as a matter of course and stays a silent cut.
    #
    # Cut anyway rather than raised on: the citizen is waiting on the message, and a
    # label short of its last word is better than no reply at all.
    def fitted_button_title(text, field:)
      value = text.to_s

      return value if value.length <= MAX_BUTTON_TITLE_LENGTH

      Rails.logger.warn(
        "[Whatsapp] #{field} \"#{value}\" is #{value.length} characters, " \
        "cut to #{MAX_BUTTON_TITLE_LENGTH}"
      )

      value.truncate(MAX_BUTTON_TITLE_LENGTH)
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

    def send_button_message(to:, body:, buttons:, header_image:)
      @client.post(
        BASE_PATH,
        body: envelope(to).merge(
          type: "interactive",
          interactive: {
            type: "button",
            **image_header(header_image),
            body: { text: body },
            action: { buttons: interactive_buttons(buttons) }
          }
        )
      )
    end

    def send_image_message(to:, image:, caption:)
      @client.post(
        BASE_PATH,
        body: envelope(to).merge(
          type: "image",
          image: image.to_h.merge({ caption: caption }.compact)
        )
      )
    end

    # WhatsApp takes a picture either way round — as a link it fetches itself,
    # or as the id of media already uploaded to it. The two shapes differ by one
    # key, so they are built here and the header is written once.
    def image_by_link(url)
      return if url.blank?

      { link: url }
    end

    def image_by_id(media_id)
      return if media_id.blank?

      { id: media_id }
    end

    def image_header(image)
      return {} if image.blank?

      { header: { type: "image", image: image }}
    end

    def interactive_buttons(buttons)
      buttons.first(MAX_BUTTONS).map do |button|
        {
          type: "reply",
          reply: {
            id: button[:id],
            title: fitted_button_title(button[:title], field: "reply button")
          }
        }
      end
    end
end
