module Whatsapp::BroadcastTemplates
  APPROVED_STATUS = "approved".freeze

  # The broadcast job always sends two variables, in this order.
  EXAMPLE_VARIABLES = ["Stadtpark neu gestalten", "https://example.org/stadtpark"].freeze

  # The card variant puts the link in a button, so its second variable is the
  # subtitle rather than a URL.
  CARD_EXAMPLE_VARIABLES = [
    "Stadtpark neu gestalten",
    "Sagen Sie uns, was aus der Fläche am Ufer werden soll."
  ].freeze

  # Announcing a new projekt is promotional under Meta's policy. Submitting it
  # as UTILITY gets the template reclassified or rejected, and repeated
  # misclassification costs the number its quality rating.
  CATEGORY = "MARKETING".freeze

  module_function

  def list
    return [] if !::Whatsapp.configured?

    response = WhatsappApi::Client.new.templates.index

    return [] if !response.success?

    build_list(response.parsed_response.to_h)
  rescue StandardError => e
    Rails.logger.error("[Whatsapp] template list failed: #{e.class} - #{e.message}")

    []
  end

  def create(name:, language:, body:)
    name = name.to_s.strip.parameterize(separator: "_")

    return if name.blank? || body.blank?

    response = WhatsappApi::Client.new.templates.create(
      name: name,
      language: language.presence || ::Whatsapp.broadcast_template_language,
      body: body,
      example_variables: EXAMPLE_VARIABLES,
      category: CATEGORY
    )

    Setting["whatsapp.broadcast_template"] = name if response.success?

    response
  end

  def create_card(name:, language:, body:, button_label:, example_image_url:)
    name = name.to_s.strip.parameterize(separator: "_")

    return if name.blank? || body.blank? || button_label.blank?

    response = WhatsappApi::Client.new.templates.create_card(
      name: name,
      language: language.presence || ::Whatsapp.broadcast_template_language,
      body: body,
      button_label: button_label,
      button_url_prefix: ::Whatsapp.projekt_url_prefix,
      example_variables: CARD_EXAMPLE_VARIABLES,
      example_image_url: example_image_url,
      category: CATEGORY
    )

    Setting["whatsapp.broadcast_card_template"] = name if response.success?

    response
  end

  def build_list(payload)
    Array(payload["waba_templates"] || payload["data"]).map do |template|
      {
        name: template["name"].to_s,
        language: template["language"].to_s,
        status: template["status"].to_s.downcase,
        approved: template["status"].to_s.downcase == APPROVED_STATUS,
        category: template["category"].to_s
      }
    end
  end

  private_class_method :build_list
end
