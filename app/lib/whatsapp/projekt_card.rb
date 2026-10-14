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

  # What one phase is called and when it closes, for the card's rows and for the
  # facts its summary is written from.
  PhaseFacts = Struct.new(:name, :ends_on, keyword_init: true)

  module_function

  # What the citizen knows each of these phases by and when each of them closes, as
  # {projekt_phase_id => PhaseFacts}. Batched because both callers hold a projekt's
  # whole set of phases and PhaseBallotQuery.by_phase answers them in one query,
  # where asking phase by phase paid for ten.
  #
  # A voting phase is named and dated by its ballot rather than by itself: a projekt
  # running four of them has four phases all titled "Abstimmung", and it is the
  # ballots that carry the names saying which is which — while projekt_phases.end_date
  # is a column a portal need never fill in, where a published poll always has the
  # window it runs in. It is also the name Whatsapp::OpenPollsQuery titles its rows
  # with, so one phase reads alike wherever the bot names it.
  #
  # Everything else falls back to the phase's own title and end_date: every other
  # phase type, and a voting phase whose ballot is unpublished or one of several.
  def phase_facts(projekt_phases)
    ballots = ::Polls::PhaseBallotQuery.by_phase(projekt_phases.map(&:id))

    projekt_phases.index_by(&:id).transform_values do |projekt_phase|
      ballot = ballots[projekt_phase.id]

      PhaseFacts.new(
        name: ballot&.name.presence || projekt_phase.title,
        ends_on: ballot&.ends_at&.to_date || projekt_phase.end_date
      )
    end
  end

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
