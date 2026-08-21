module Whatsapp::SupportRecap
  # What a citizen is told once their support is registered, composed from the
  # proposal rather than written by the model.
  #
  # There is nothing of the citizen's own in this one — support is a tap, not a
  # text — so what it guarantees is narrower than the draft and comment blocks and
  # still worth guaranteeing: that the proposal named is the proposal that was
  # voted on, and that the count is the one the projekt page will show. A model
  # writing this from a tool's return value is a model that can name the proposal
  # the conversation was about a message ago instead of the one it just acted on.
  #
  # Support cannot be withdrawn, which is why there is no block before the fact
  # here: what the citizen confirms is a proposal they were already shown by
  # whichever tool found it, and the pill they tap carries its id.

  SCOPE = "whatsapp.bot.support".freeze

  LABEL_KEYS = %w[registered supports].freeze

  module_function

  def block(account:, proposal:, supports:)
    return if proposal.blank?

    labels = ::Whatsapp::MessageBlock.labels(
      account: account, scope: SCOPE, keys: LABEL_KEYS
    )

    ::Whatsapp::MessageBlock.compose(
      [
        ::Whatsapp::MessageBlock.labelled_lines(
          [
            [labels["registered"], proposal.title],
            [labels["supports"], supports]
          ]
        ),
        ::Whatsapp::PublishedResourceUrl.call(proposal)
      ]
    )
  end
end
