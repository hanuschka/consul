class Whatsapp::CreateBroadcastTemplateService < ApplicationService
  # The broadcast job always sends two variables, in this order.
  EXAMPLE_VARIABLES = ["Stadtpark neu gestalten", "https://example.org/stadtpark"].freeze

  def initialize(name:, language:, body:)
    @name = name.to_s.strip.parameterize(separator: "_")
    @language = language.presence || ::Whatsapp.broadcast_template_language
    @body = body
  end

  def call
    return if @name.blank? || @body.blank?

    response = WhatsappApi::Client.new.templates.create(
      name: @name,
      language: @language,
      body: @body,
      example_variables: EXAMPLE_VARIABLES
    )

    Setting["whatsapp.broadcast_template"] = @name if response.success?

    response
  end
end
