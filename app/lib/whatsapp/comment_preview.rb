module Whatsapp::CommentPreview
  # A comment as it will be posted, shown before it goes anywhere. The same
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
  #
  # The comment is composed once, for the message that asks whether it may be
  # posted. What follows is a single sentence, for the reason the contributions
  # follow: they have just read their own words and answered the question under
  # them, so sending the words back a second time buries the only new fact.

  SCOPE = "whatsapp.bot.comment".freeze

  CONFIRMATION_LABEL_KEYS = %w[on_proposal].freeze

  module_function

  # The comment as it stands, for the message that asks whether it may be posted.
  def confirmation_block(conversation:)
    pending = conversation.pending_comment.to_h

    return if pending["text"].blank?

    labels = ::Whatsapp::MessageBlock.labels(
      account: conversation.whatsapp_account, scope: SCOPE, keys: CONFIRMATION_LABEL_KEYS
    )

    ::Whatsapp::MessageBlock.compose(
      [
        ::Whatsapp::MessageBlock.verbatim(pending["text"]),
        ::Whatsapp::MessageBlock.labelled_lines(
          [[labels["on_proposal"], proposal_title(pending["proposal_id"])]]
        )
      ]
    )
  end

  # Once it is on the page: the sentence and the address, and nothing they have
  # already read. The comment's own address rather than the proposal's, so tapping
  # it lands on what they just wrote.
  def posted_confirmation(conversation:, url:)
    ::Whatsapp::MessageBlock.closing_line(
      account: conversation.whatsapp_account, scope: SCOPE, key: "online", value: url
    )
  end

  # A comment a moderation rule hid on creation has no visible place on the page
  # yet, so this offers no address — the same rule the contributions follow.
  def awaiting_review_confirmation(conversation:)
    ::Whatsapp::MessageBlock.closing_line(
      account: conversation.whatsapp_account, scope: SCOPE, key: "awaiting_review"
    )
  end

  # The stashed words and the proposal they are meant for. Both, because a comment
  # confirmed for one proposal must not be posted under another.
  def digest(conversation:)
    pending = conversation.pending_comment.to_h

    return if pending["text"].blank?

    ::Whatsapp::MessageBlock.digest([pending["text"], pending["proposal_id"]])
  end

  # Read back rather than stashed with the text: a proposal retired or renamed
  # between writing and posting should show the citizen what it is called now.
  def proposal_title(proposal_id)
    ::Proposal.find_by(id: proposal_id)&.title
  end

  private_class_method :proposal_title
end
