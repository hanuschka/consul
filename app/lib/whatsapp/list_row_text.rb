module Whatsapp::ListRowText
  # The two lines of a list row, for a name longer than the title holds. The title
  # used to be the name cut at its twenty-fourth character, and two ballots named
  # "WhatsApp-Test: Grundfragen …" came out as the same row twice, over the same
  # line underneath — the part of the names that tells them apart was the part
  # that was cut. Now the name is split rather than cut: the title keeps its
  # opening words and the line underneath carries on where the title stopped,
  # ahead of the notes, so the words that differ are on the screen.
  #
  # Split at a word boundary, because the second line reads as the continuation
  # of the first. A name whose first word alone outgrows the title has no such
  # boundary, and there the title is cut mid-word and the line underneath
  # carries the name whole instead — which is how the citizen's own contribution
  # list already reads.
  NOTE_SEPARATOR = " · ".freeze

  # How much of the line underneath the rest of a split name keeps whatever the
  # notes want, so a long note cannot push out the words that tell two rows apart.
  MIN_REST_LENGTH = 24

  module_function

  # {title:, description:} for a row, or nil for a blank name. `notes` are what
  # the line underneath says besides the rest of the name — an action, a status,
  # a date — joined in order and dropped where blank.
  def call(name:, notes: [], length: ::Whatsapp::AssistantActions::MAX_ROW_TITLE_LENGTH)
    text = name.to_s.squish

    return if text.blank?

    title, rest = split(text, length)

    { title: title, description: description(rest, notes) }
  end

  # The title and whatever of the name it could not hold. A boundary in the first
  # half of the title is no boundary worth splitting at: the title would say
  # almost nothing.
  def split(text, length)
    return [text, nil] if text.length <= length

    omission = ::Whatsapp::AssistantActions::TRUNCATION_OMISSION
    room = length - omission.length
    boundary = text.rindex(" ", room)

    if boundary.nil? || boundary < room / 2
      return [text.truncate(length, omission: omission), text]
    end

    ["#{text[0...boundary].rstrip}#{omission}", text[boundary..].strip]
  end

  def description(rest, notes)
    maximum = ::Whatsapp::MAX_ROW_DESCRIPTION_LENGTH
    omission = ::Whatsapp::AssistantActions::TRUNCATION_OMISSION
    note_text = Array(notes).map { |note| note.to_s.squish }.compact_blank.join(NOTE_SEPARATOR)

    if rest.blank?
      return note_text.presence&.truncate(maximum, omission: omission)
    end

    rest_room = maximum - (note_text.empty? ? 0 : note_text.length + NOTE_SEPARATOR.length)
    kept_rest = rest.truncate([rest_room, MIN_REST_LENGTH].max, omission: omission)

    [kept_rest, note_text.presence]
      .compact
      .join(NOTE_SEPARATOR)
      .truncate(maximum, omission: omission)
  end
end
