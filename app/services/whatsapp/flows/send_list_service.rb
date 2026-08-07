class Whatsapp::Flows::SendListService < ApplicationService
  # The shape every "here is a list of things" reply shares: send the rows, or
  # explain the emptiness. Composed into rather than inherited from, so each
  # caller stays a row builder and nothing else.
  #
  # An empty list now answers with plain text. The catalog has no portal menu to
  # fall back to — the way on from a dead end is the help command, which the
  # empty copy names.
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
      Whatsapp::Outbound.text(account: @conversation.whatsapp_account, body: @empty_body)
    end
end
