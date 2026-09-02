module Whatsapp::ProjektCard
  # The broadcast template's second body variable, which Meta rejects when
  # empty. Chat cards get their own, smaller budget from the caller: an
  # interactive body holds 1024 characters for title, subtitle and link
  # together.
  TEMPLATE_SUBTITLE_MAX_LENGTH = 900

  # Below this much page text the card's two-or-three-sentence summary already
  # carries the whole description, so a "view projekt" pill would have nothing to
  # tell that the card does not.
  MORE_TO_TELL_MIN_LENGTH = 300

  # Content blocks carry {{projekt_map}}-style placeholders, which are markup
  # rather than text.
  CONTENT_PLACEHOLDER = /\{\{.*?\}\}/

  module_function

  def subtitle(projekt, max_length: TEMPLATE_SUBTITLE_MAX_LENGTH)
    projekt.page&.subtitle.to_s.squish.truncate(max_length).presence
  end

  def image_url(projekt)
    ::Whatsapp.header_image_url(projekt.page&.image&.attachment)
  end

  # The projekt's own text, flattened and cut. Read through Projekt#page_content
  # rather than off the page, because a projekt in content-block mode leaves
  # pages.content empty — reading the column would describe those projekts by
  # their subtitle alone.
  def description_text(projekt, length:)
    ::Whatsapp.plain_text(
      projekt.page_content.to_s.gsub(CONTENT_PLACEHOLDER, " "), length: length
    ).presence
  end

  # Whether a "view projekt" pill has anything to say beyond the card it sits
  # under: a description longer than the card's summary can hold, or phases to
  # report on. A thin projekt with no phases is fully told by the card itself, so
  # the pill is not offered and the remaining ones move up.
  # The phase query first: it is one indexed existence check, where the description
  # side loads every content block and sanitizes the lot. The two are independent,
  # so asking the cheap one first is free and skips the render for every projekt
  # that has a phase to report on.
  def tells_more?(projekt)
    return true if ::Whatsapp::ProjektPhasesQuery.new(projekt: projekt).exists?

    long_description?(projekt)
  end

  def long_description?(projekt)
    text = description_text(projekt, length: MORE_TO_TELL_MIN_LENGTH + 1)

    text.to_s.length > MORE_TO_TELL_MIN_LENGTH
  end
end
