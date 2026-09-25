module Whatsapp::SupportRecap
  # What a citizen is told once their support has been registered or taken back,
  # composed from the proposal rather than written by the model.
  #
  # There is nothing of the citizen's own in this one — a support is a tap, not a
  # text — so what it guarantees is narrower than the draft and comment blocks and
  # still worth guaranteeing: that the proposal named is the proposal that was voted
  # on, and that the count is the one the projekt page will show. A model writing
  # this from a tool's return value is a model that can name the proposal the
  # conversation was about a message ago instead of the one it just acted on.
  #
  # Both directions are the same shape on purpose — the line naming the proposal,
  # the line naming the count, the address — because they are the same fact reported
  # twice with the number moved. Two entry points rather than one with a direction
  # to read, so the call site says which way it went.

  SCOPE = "whatsapp.bot.support".freeze

  COUNT_KEY = "supports".freeze

  module_function

  def registered_block(account:, proposal:, supports:)
    block(account: account, proposal: proposal, supports: supports, title_key: "registered")
  end

  def withdrawn_block(account:, proposal:, supports:)
    block(account: account, proposal: proposal, supports: supports, title_key: "withdrawn")
  end

  def block(account:, proposal:, supports:, title_key:)
    return if proposal.blank?

    labels = ::Whatsapp::MessageBlock.labels(
      account: account, scope: SCOPE, keys: [title_key, COUNT_KEY]
    )

    ::Whatsapp::MessageBlock.compose(
      [
        ::Whatsapp::MessageBlock.labelled_lines(
          [
            [labels[title_key], proposal.title],
            [labels[COUNT_KEY], supports]
          ]
        ),
        ::Whatsapp::PublishedResourceUrl.call(proposal)
      ]
    )
  end

  private_class_method :block
end
