module Whatsapp::BroadcastTemplates
  APPROVED_STATUS = "approved".freeze

  # The only status the tab offers to delete. Meta keeps a rejected template on
  # the account forever and counts it against the limit, while every other
  # status is either in use or still on its way to being usable.
  REJECTED_STATUS = "rejected".freeze

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

  # Which broadcast setting a template belongs to. The card variant carries the
  # projekt image and its link in a button; the text one is the plain fallback.
  TEXT_KIND = "text".freeze
  CARD_KIND = "card".freeze

  SETTING_KEYS_BY_KIND = {
    TEXT_KIND => "whatsapp.broadcast_template",
    CARD_KIND => "whatsapp.broadcast_card_template"
  }.freeze

  module_function

  # The name stored for one broadcast kind, mirroring
  # NotificationTemplates.name_for so a slot row can read either catalog the
  # same way.
  def name_for(kind)
    Setting[SETTING_KEYS_BY_KIND.fetch(kind)].presence
  end

  # Every name either catalog can have stored, for the check that refuses to
  # delete a template something is still sending with.
  def configured_names
    broadcast_names = SETTING_KEYS_BY_KIND.keys.map { |kind| name_for(kind) }
    push_names =
      ::Whatsapp::NotificationTemplates::KINDS.map do |kind|
        ::Whatsapp::NotificationTemplates.name_for(kind)
      end

    (broadcast_names + push_names).compact.uniq
  end

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

    # Deliberately not activated here. A 2xx only means Meta accepted the
    # submission; approval takes hours, and broadcasting a pending template
    # fails while still marking the projekt as announced. The templates tab
    # offers "use" once the listing reports it approved, and that path sets the
    # language alongside the name so the two cannot drift.
    response
  end

  # Rejected templates are not free: they stay on the account for good and count
  # against its template limit, so the tab needs a way to clear them.
  #
  # Rescued like `list` rather than raised: a failure here costs an admin the
  # button, and the page has to come back to say so instead of 500-ing on a
  # provider that answered slowly.
  def delete(name:)
    return if !::Whatsapp.configured? || name.blank?

    WhatsappApi::Client.new.templates.destroy(name: name)
  rescue StandardError => e
    Rails.logger.error("[Whatsapp] template delete failed: #{e.class} - #{e.message}")

    nil
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

    # Not activated here, for the same reason the text variant is not: Meta
    # accepting the submission is not Meta approving it, and broadcasting a
    # pending template fails while still marking the projekt announced.


    response
  end

  def build_list(payload)
    Array(payload["waba_templates"] || payload["data"]).map do |template|
      {
        name: template["name"].to_s,
        language: template["language"].to_s,
        status: template["status"].to_s.downcase,
        approved: template["status"].to_s.downcase == APPROVED_STATUS,
        category: template["category"].to_s,
        kind: kind_of(template)
      }
    end
  end

  # The card variant is the one Meta reports with an image header, which is
  # exactly what create_card submits. Told apart here because the two kinds are
  # stored in different settings, and offering "use" without knowing which
  # would write the wrong one.
  def kind_of(template)
    header = Array(template["components"]).find { |component| component["type"].to_s.casecmp?("HEADER") }

    return CARD_KIND if header && header["format"].to_s.casecmp?("IMAGE")

    TEXT_KIND
  end

  private_class_method :build_list, :kind_of
end
