class Whatsapp::SendTemplateService < ApplicationService
  def initialize(account:, name:, variables: [], language: nil, projekt_id: nil)
    @account = account
    @name = name
    @variables = variables
    @language = language || ::Whatsapp.broadcast_template_language
    @projekt_id = projekt_id
  end

  def call
    response =
      WhatsappApi::Client
        .new
        .messages
        .send_template(
          to: @account.wa_id,
          name: @name,
          language: @language,
          variables: @variables
        )

    WhatsappMessage.record_outbound!(
      account: @account,
      kind: "template",
      body: "#{@name}: #{@variables.join(' | ')}",
      projekt_id: @projekt_id,
      response:
    )
  end
end
