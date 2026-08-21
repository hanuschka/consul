module Whatsapp::CommentPreview
  # A comment as it will be posted, and again once it is on the page. The same
  # guarantee the draft blocks make, for the same reason: the citizen's name goes
  # under this on a public page and a comment cannot be taken back from a chat.
  #
  # This used to be argued the other way — a comment is short enough that showing
  # it back was held to cost more taps than writing it did. What that reasoning
  # missed is that the tool took the text as a parameter, so the words posted were
  # whichever ones the model passed, and "ja" under a citizen's name is exactly the
  # failure the length argument said was not worth a tap.
  #
  # Composed off the stash rather than the record, because there is no record until
  # it is posted: Whatsapp::Conversation#pending_comment holds the citizen's words
  # between the two.

  SCOPE = "whatsapp.bot.comment".freeze

  LABEL_KEYS = %w[on_proposal online awaiting_review].freeze

  module_function

  # The comment as it stands, for the message that asks whether it may be posted.
  def confirmation_block(conversation:)
    compose(conversation: conversation, closing_keys: [])
  end

  # The same block once it is on the page, with the address written out. The
  # comment's own address rather than the proposal's, so tapping it lands on what
  # they just wrote.
  def posted_block(conversation:, url:)
    compose(conversation: conversation, closing_keys: ["online"], closing_value: url)
  end

  # A comment a moderation rule hid on creation has no visible place on the page
  # yet, so this block offers no address — the same rule the contributions follow.
  def awaiting_review_block(conversation:)
    compose(conversation: conversation, closing_keys: ["awaiting_review"])
  end

  # The stashed words and the proposal they are meant for. Both, because a comment
  # confirmed for one proposal must not be posted under another.
  def digest(conversation:)
    pending = conversation.pending_comment.to_h

    return if pending["text"].blank?

    ::Whatsapp::MessageBlock.digest([pending["text"], pending["proposal_id"]])
  end

  def compose(conversation:, closing_keys:, closing_value: nil)
    pending = conversation.pending_comment.to_h

    return if pending["text"].blank?

    labels = ::Whatsapp::MessageBlock.labels(
      account: conversation.whatsapp_account, scope: SCOPE, keys: LABEL_KEYS
    )

    ::Whatsapp::MessageBlock.compose(
      [
        ::Whatsapp::MessageBlock.verbatim(pending["text"]),
        ::Whatsapp::MessageBlock.labelled_lines(
          [[labels["on_proposal"], proposal_title(pending["proposal_id"])]]
        ),
        closing_line(keys: closing_keys, labels: labels, value: closing_value)
      ]
    )
  end

  # Read back rather than stashed with the text: a proposal retired or renamed
  # between writing and posting should show the citizen what it is called now.
  def proposal_title(proposal_id)
    ::Proposal.find_by(id: proposal_id)&.title
  end

  def closing_line(keys:, labels:, value:)
    line = keys.map { |key| labels[key] }.compact_blank.join(" ")

    return if line.blank?

    [line, value].compact_blank.join("\n")
  end

  private_class_method :compose, :proposal_title, :closing_line
end
