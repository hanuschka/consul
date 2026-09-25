module Whatsapp::DraftPreview
  # The contribution as it is stored, composed here rather than described to the
  # assistant. What the citizen confirms has to be the record itself: a body the
  # model writes is a body it can shorten, reorder or improve, and a citizen who
  # agrees to a rephrasing has agreed to something other than what goes online.
  #
  # So the title and the text are read off the record and never travel through a
  # model — not the routing one that would quote them, and not the translating one
  # either: they are the citizen's own words, already in the citizen's own
  # language.
  #
  # The whole contribution is composed once, for the message that asks whether it
  # may go in. What follows a publish is a single sentence, because the citizen
  # has just read that message and answered it: repeating the contribution under
  # their own confirmation buries the one fact the second message carries.
  # Whatsapp::MessageBlock owns the composition rules this shares with the comment
  # and support blocks.

  SCOPE = "whatsapp.bot.preview".freeze

  CONFIRMATION_LABEL_KEYS = %w[projekt phase attachments photo location].freeze

  module_function

  # The draft as it stands, for the message that asks whether it may go in.
  def confirmation_block(conversation:)
    resource = conversation.draft_resource

    return if resource.blank?

    labels = ::Whatsapp::MessageBlock.labels(
      account: conversation.whatsapp_account, scope: SCOPE, keys: CONFIRMATION_LABEL_KEYS
    )

    ::Whatsapp::MessageBlock.compose(
      [
        "*#{resource.title}*",
        description_text(resource),
        meta_lines(conversation: conversation, resource: resource, labels: labels)
      ]
    )
  end

  # Once it is online: the sentence and the address, and nothing they have already
  # read. WhatsApp makes a written-out address tappable, so it needs no button of
  # its own — and a button would be the only thing on the message it sat on.
  def published_confirmation(conversation:, url:)
    ::Whatsapp::MessageBlock.closing_line(
      account: conversation.whatsapp_account, scope: SCOPE, key: "online", value: url
    )
  end

  # A contribution held for review has no public page, so this deliberately
  # carries no address at all: a link onto a login wall or an error page is worse
  # than being told plainly that there is nothing to open yet.
  def awaiting_review_confirmation(conversation:)
    ::Whatsapp::MessageBlock.closing_line(
      account: conversation.whatsapp_account, scope: SCOPE, key: "awaiting_review"
    )
  end

  # What the citizen was shown, reduced to the facts the block displays.
  def digest(conversation:)
    resource = conversation.draft_resource

    return if resource.blank?

    ::Whatsapp::MessageBlock.digest(
      [
        resource.title,
        description_text(resource),
        conversation.projekt_phase_id,
        image_blob_id(resource),
        pin_coordinates(resource)
      ]
    )
  end

  # Which projekt and which participation option it goes into, and what is
  # attached that the citizen never typed. The last of those is the point of the
  # group: a photo and a pin are part of what they are confirming, and neither
  # appears anywhere in the text.
  def meta_lines(conversation:, resource:, labels:)
    phase = conversation.projekt_phase

    ::Whatsapp::MessageBlock.labelled_lines(
      [
        [labels["projekt"], phase.present? ? ::Whatsapp::ProjektLink.title(phase.projekt) : nil],
        [labels["phase"], phase&.title],
        [labels["attachments"], attached_names(resource: resource, labels: labels)]
      ]
    )
  end

  def attached_names(resource:, labels:)
    [
      image_blob_id(resource).present? ? labels["photo"] : nil,
      pin_coordinates(resource).present? ? labels["location"] : nil
    ].compact_blank.join(", ").presence
  end

  def description_text(resource)
    ::Whatsapp::MessageBlock.verbatim(resource.description)
  end

  def image_blob_id(resource)
    resource.image&.attachment&.blob&.id
  end

  def pin_coordinates(resource)
    pin = resource.map_location

    return if pin.blank?

    [pin.latitude, pin.longitude].join(",")
  end

  private_class_method :meta_lines, :attached_names
  private_class_method :description_text, :image_blob_id, :pin_coordinates
end
