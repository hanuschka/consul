module Whatsapp::ProjektCard
  # WhatsApp fetches the header picture itself, from us, while the send is in
  # flight, and rejects the whole message over anything it cannot render. A
  # projekt whose picture is a webp or an oversized file is therefore sent
  # without one rather than not at all.
  IMAGE_CONTENT_TYPES = ["image/jpeg", "image/png"].freeze
  IMAGE_MAX_BYTES = 5.megabytes

  # The broadcast template's second body variable, which Meta rejects when
  # empty. Chat cards get their own, smaller budget from the caller: an
  # interactive body holds 1024 characters for title, subtitle and link
  # together.
  TEMPLATE_SUBTITLE_MAX_LENGTH = 900

  module_function

  def subtitle(projekt, max_length: TEMPLATE_SUBTITLE_MAX_LENGTH)
    projekt.page&.subtitle.to_s.squish.truncate(max_length).presence
  end

  # Nil rather than a placeholder when the picture is missing or unusable:
  # every caller has a shape it falls back to, and a broken image is worse
  # than none.
  def image_url(projekt)
    attachment = usable_image(projekt)

    return if attachment.blank?

    Rails.application.routes.url_helpers.rails_blob_url(attachment, **UrlOptions.default.to_h)
  end

  def usable_image(projekt)
    attachment = projekt.page&.image&.attachment

    return if attachment.blank? || !attachment.attached?
    return if !IMAGE_CONTENT_TYPES.include?(attachment.blob.content_type)
    return if attachment.blob.byte_size > IMAGE_MAX_BYTES

    attachment
  end
end
