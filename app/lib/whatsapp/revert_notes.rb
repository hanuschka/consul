module Whatsapp::RevertNotes
  # What the assistant is told once the change a citizen had asked for is taken
  # back by the cancel pill, the counterpart of Whatsapp::DiscardNotes. The pill
  # under a request for a change reads "Änderung verwerfen", and it used to be
  # answered like any other cancel: the whole comment gone and "abgebrochen".
  #
  # The preview is named as the way on rather than sent from here, so the assistant
  # still decides what the message after the revert says and which buttons it
  # carries.
  #
  # Read before the revert, which closes the change it describes.
  COMMENT = "Only the change they had asked for has been dropped: their comment is back " \
            "exactly as they last read it in its preview, and nothing was posted or " \
            "discarded. Show it to them again with show_comment_for_confirmation, with the " \
            "same buttons as under that preview, and let its question say in a few words " \
            "that the change was dropped. Never say anything was cancelled or deleted.".freeze

  DRAFT = "Only the change they had asked for has been dropped: their draft is back " \
          "exactly as they last read it in its preview, and nothing was published or " \
          "discarded. Show it to them again with show_draft_for_confirmation, with the " \
          "same buttons as under that preview, and let its question say in a few words " \
          "that the change was dropped. Never say anything was cancelled or deleted.".freeze

  module_function

  def for(conversation)
    case conversation.revision_kind
    when "comment" then COMMENT
    when "draft" then DRAFT
    end
  end
end
