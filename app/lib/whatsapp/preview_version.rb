module Whatsapp::PreviewVersion
  # Which version of a draft or a comment a publishing pill was offered under,
  # carried in the pill's own id. A pill stays tappable for as long as it sits in
  # the chat and the draft can change under it: a citizen who scrolls up to an
  # earlier preview and taps the publishing pill there is answering a text that is
  # no longer the one that would go in. The stored digest only says what was shown
  # last, so without this a tap under an older preview and a tap under the newest
  # one read exactly alike.
  #
  # A prefix of the preview's digest rather than the whole of it: WhatsApp caps a
  # button id, and twelve hex characters are plenty to tell two versions of one
  # draft apart.
  TAG_LENGTH = 12

  DRAFT_ACTIONS = %i[draft_publish submit_final].freeze
  COMMENT_ACTIONS = %i[comment_post].freeze

  module_function

  # The tag a publishing pill offered now carries. Nil for any other pill, and
  # where there is nothing to publish.
  def tag(action:, conversation:)
    digest(action: action, conversation: conversation)&.first(TAG_LENGTH)
  end

  # Whether a tapped publishing pill was offered under a version that no longer
  # stands. An untagged one is from before the tags existed and stays with
  # PublishDraft's own digest check, and so does one whose draft or comment is
  # gone: there is nothing to show again, and the assistant can say so.
  def outdated?(action:, param:, conversation:)
    return false if param.blank?

    current = tag(action: action, conversation: conversation)

    current.present? && current != param
  end

  def draft?(action)
    DRAFT_ACTIONS.include?(action)
  end

  def comment?(action)
    COMMENT_ACTIONS.include?(action)
  end

  def digest(action:, conversation:)
    if draft?(action)
      ::Whatsapp::DraftPreview.digest(conversation: conversation)
    elsif comment?(action)
      ::Whatsapp::CommentPreview.digest(conversation: conversation)
    end
  end

  private_class_method :digest
end
