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
  # The same block is sent twice — before publishing and after it — for the reason
  # the ticket exists: two renderings of one record are two chances for the second
  # to differ from the first. Whatsapp::MessageBlock owns the composition rules
  # this shares with the comment and support blocks.

  SCOPE = "whatsapp.bot.preview".freeze

  LABEL_KEYS = %w[
    projekt
    phase
    attachments
    photo
    location
    online
    awaiting_review
  ].freeze

  module_function

  # The draft as it stands, for the message that asks whether it may go in.
  def confirmation_block(conversation:)
    compose(conversation: conversation, closing_keys: [])
  end

  # The same block once it is online, with the address written out. WhatsApp makes
  # a written-out address tappable, so it needs no button of its own — and a button
  # would be the only thing on the message it sat on.
  def published_block(conversation:, url:)
    compose(conversation: conversation, closing_keys: ["online"], closing_value: url)
  end

  # A contribution held for review has no public page, so this block deliberately
  # carries no address at all: a link onto a login wall or an error page is worse
  # than being told plainly that there is nothing to open yet.
  def awaiting_review_block(conversation:)
    compose(conversation: conversation, closing_keys: ["awaiting_review"])
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

  def compose(conversation:, closing_keys:, closing_value: nil)
    resource = conversation.draft_resource

    return if resource.blank?

    labels = ::Whatsapp::MessageBlock.labels(
      account: conversation.whatsapp_account, scope: SCOPE, keys: LABEL_KEYS
    )

    ::Whatsapp::MessageBlock.compose(
      [
        "*#{resource.title}*",
        description_text(resource),
        meta_lines(conversation: conversation, resource: resource, labels: labels),
        closing_line(keys: closing_keys, labels: labels, value: closing_value)
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

  def closing_line(keys:, labels:, value:)
    line = keys.map { |key| labels[key] }.compact_blank.join(" ")

    return if line.blank?

    [line, value].compact_blank.join("\n")
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

  private_class_method :compose, :meta_lines, :attached_names, :closing_line
  private_class_method :description_text, :image_blob_id, :pin_coordinates
end
