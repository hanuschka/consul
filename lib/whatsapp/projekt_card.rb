module Whatsapp::ProjektCard
  # The broadcast template's second body variable, which Meta rejects when
  # empty. Chat cards get their own, smaller budget from the caller: an
  # interactive body holds 1024 characters for title, subtitle and link
  # together.
  TEMPLATE_SUBTITLE_MAX_LENGTH = 900

  module_function

  def subtitle(projekt, max_length: TEMPLATE_SUBTITLE_MAX_LENGTH)
    projekt.page&.subtitle.to_s.squish.truncate(max_length).presence
  end

  def image_url(projekt)
    ::Whatsapp.header_image_url(projekt.page&.image&.attachment)
  end
end
