class WhatsappApi::Resources::Templates
  BASE_PATH = "/v1/configs/templates".freeze
  DEFAULT_CATEGORY = "UTILITY".freeze

  def initialize(client)
    @client = client
  end

  def index
    @client.get(BASE_PATH)
  end

  def create(name:, language:, body:, example_variables: [], category: DEFAULT_CATEGORY)
    @client.post(
      BASE_PATH,
      body: {
        name: name,
        language: language,
        category: category,
        components: [body_component(body, example_variables)]
      }
    )
  end

  # The projekt card: image header, text body, one URL button whose fixed prefix
  # gets the projekt id appended at send time.
  #
  # Meta's Graph API wants an uploaded media handle as the header example
  # (`header_handle`, from the resumable upload API); 360dialog's v1 endpoint
  # takes a public URL instead. If a submission comes back rejected over the
  # example, create the template in the 360dialog console and only store its
  # name in `whatsapp.broadcast_card_template`.
  def create_card(
    name:, language:, body:, button_label:, button_url_prefix:,
    example_variables: [], example_image_url: nil, example_button_variable: "1",
    category: DEFAULT_CATEGORY
  )
    @client.post(
      BASE_PATH,
      body: {
        name: name,
        language: language,
        category: category,
        components: [
          header_image_component(example_image_url),
          body_component(body, example_variables),
          url_button_component(button_label, button_url_prefix, example_button_variable)
        ]
      }
    )
  end

  private

    def header_image_component(example_image_url)
      component = { type: "HEADER", format: "IMAGE" }

      return component if example_image_url.blank?

      component.merge(example: { header_url: [example_image_url] })
    end

    # The URL carries its variable as a suffix, which is the only dynamic form
    # Meta approves: a fixed prefix plus one placeholder.
    def url_button_component(button_label, button_url_prefix, example_button_variable)
      {
        type: "BUTTONS",
        buttons: [
          {
            type: "URL",
            text: button_label,
            url: "#{button_url_prefix}{{1}}",
            example: ["#{button_url_prefix}#{example_button_variable}"]
          }
        ]
      }
    end

    def body_component(body, example_variables)
      component = { type: "BODY", text: body }

      return component if example_variables.blank?

      component.merge(example: { body_text: [example_variables] })
    end
end
