class Whatsapp::Steps::SendListService < ApplicationService
  # The shape every "here is a list of things" reply shares: send the rows, or
  # explain the emptiness and offer the way back. Composed into rather than
  # inherited from, so each caller stays a row builder and nothing else.
  def initialize(conversation:, rows:, body:, button_label:, empty_body:)
    @conversation = conversation
    @rows = rows
    @body = body
    @button_label = button_label
    @empty_body = empty_body
  end

  def call
    return send_empty if @rows.empty?

    Whatsapp::Outbound.list(
      account: @conversation.whatsapp_account,
      body: @body,
      button_label: @button_label,
      rows: @rows
    )
  end

  private

    def send_empty
      Whatsapp::Outbound.recovery(conversation: @conversation, body: @empty_body, actions: [:menu])
    end
end
