class Whatsapp::AiAssistant::ProjektSummaryService < ApplicationService
  # What a projekt is about, said the way someone who knows it would say it.
  # Every surface that names a projekt used to hand the citizen the page's own
  # subtitle — the first 900 characters of editorial copy written for a web page,
  # which on a projekt in content-block mode is routinely empty. A citizen who
  # picked a name off a list was then asked how they wanted to take part without
  # having been told what they had picked.
  #
  # Built from the projekt's whole context rather than from its description: the
  # page opening, the phases and their dates, what is open to vote on, what has
  # happened and what came of it. That is also why it is not a shortening — the
  # facts it names are spread over five queries and none of them is the
  # description.
  REQUEST_TIMEOUT_SECONDS = 15

  # How much of the page reaches the model. Past this the page is a document
  # rather than an introduction, and its opening is what an introduction is
  # built from anyway.
  PAGE_LENGTH = 2000

  # Held for a day, not a month. Half of what the summary says is what is open
  # *right now*, and a sentence built on "still three weeks to go" is wrong long
  # before the projekt is edited. The fingerprint below catches the edits; this
  # catches the passage of time.
  CACHE_EXPIRY = 1.day

  # Enough of each list to characterise the projekt. A summary that has read ten
  # milestones says the same thing as one that has read three, at three times the
  # prompt.
  MAX_CONTEXT_ROWS = 3

  # The lengths a summary is ever generated at. Two callers ask about the same
  # projekt a hundred characters apart — the card subtracts the title and the link
  # from WhatsApp's 1024, describe_projekt asks for a flat 800 — and keyed on the
  # asked-for number that is two completions a day for two paragraphs saying the
  # same thing. On a rung they are one.
  #
  # Floored to a rung rather than rounded to one: generated for the rung above,
  # the summary would overrun what the card has left after its title and link,
  # and the card is where the budget is real rather than nominal. A caller asking
  # for less than the lowest rung is answered at its own length — there is no rung
  # under it to fall to.
  LENGTH_RUNGS = [400, 600, 800].freeze

  def initialize(projekt:, length:)
    @projekt = projekt
    @length = length
  end

  # Always answers with something a card can print. The page subtitle it
  # replaces is also its fallback, so an unreachable provider costs the citizen
  # the thin subtitle they had before rather than a projekt with no description
  # at all.
  def call
    return fallback if @projekt.blank?
    return fallback if !::Ai::Settings.ai_available?
    return fallback if context.blank?

    cached_summary || fallback
  end

  private

    # What the model is asked for, what the summary is cut to, and what the cache
    # is keyed on — one number, because keying on the rung while generating at the
    # caller's own length would let whichever caller arrived first decide how long
    # every later one's summary was.
    def target_length
      @target_length ||= LENGTH_RUNGS.select { |rung| rung <= @length }.max || @length
    end

    # The page's own subtitle, at the caller's full length rather than the rung:
    # nothing is generated or cached here, so there is nothing to share and no
    # reason to hand back less than there is room for.
    def fallback
      ::Whatsapp::ProjektCard.subtitle(@projekt, max_length: @length)
    end

    # Written back only when the model actually produced something, so a failed
    # generation is retried on the next send rather than cached as a permanent
    # thin subtitle.
    def cached_summary
      cached = Rails.cache.read(cache_key)

      return cached if cached.present?

      summary = generate

      return if summary.blank?

      Rails.cache.write(cache_key, summary, expires_in: CACHE_EXPIRY)

      summary
    end

    # The editorial stamp rather than updated_at, which nightly stats refreshes
    # and deploy-time setting writes touch on every projekt in the portal — keyed
    # on it, a summary would be regenerated for projekts nobody had edited.
    # Backfilled nowhere, so updated_at still stands in where it is missing.
    #
    # The phase digest is the other half of the key: a phase that closed
    # overnight changes what the summary may say without changing the projekt
    # row at all.
    def cache_key
      [
        "whatsapp/projekt_summary",
        @projekt.id,
        (@projekt.content_updated_at || @projekt.updated_at).to_i,
        phase_fingerprint,
        target_length
      ]
    end

    def phase_fingerprint
      states = projekt_phases.map do |projekt_phase|
        [
          projekt_phase.id,
          projekt_phase.end_date,
          ::Whatsapp::EligiblePhasesQuery.eligible?(projekt_phase)
        ].join(":")
      end

      Digest::MD5.hexdigest(states.join("|"))
    end

    def generate
      summary = response_content["summary"].to_s.squish

      return if summary.blank?

      # The rung is what the surface has room for, and a model asked for "about
      # 300 characters" will sometimes hand back 380. Cut rather than re-asked:
      # the sentence is already whole, and the card has a hard budget it shares
      # with the title and the link.
      summary.truncate(target_length)
    rescue StandardError => e
      Rails.logger.error("[Whatsapp] projekt summary failed: #{e.class} - #{e.message}")

      nil
    end

    def response_content
      ::Ai::RubyLlmFactory
        .fast_chat(REQUEST_TIMEOUT_SECONDS)
        .with_schema(output_schema)
        .with_instructions(instructions)
        .ask(context)
        .content
        .to_h
    end

    # Not a shortening of the description, so the instructions say what to build
    # from instead — and say plainly that a fact absent from the context is a
    # fact the summary may not contain. A citizen asked to decide whether to take
    # part on the strength of an invented deadline is worse served than one told
    # nothing.
    #
    # The opener is where a generated summary gives itself away: asked project by
    # project, a model reaches for the same frame every time, and a portal whose
    # forty projekts all begin "In dem Projekt geht es um" reads as a form. So
    # the frame is forbidden rather than the repetition discouraged.
    def instructions
      <<~TEXT
        You are introducing a participation projekt to a citizen in a WhatsApp chat, in at most
        #{target_length} characters. You are given everything the portal holds about it.

        Say what the projekt is about, and — where the facts below support it — what stage it is at
        and what is open to take part in right now.

        Rules:
        - Write in #{output_language}. Quote names, titles and places as they are spelled below.
        - Say nothing that is not in the facts below. No figures, deadlines, results or intentions
          of your own. Where the facts are thin, a shorter introduction is the correct answer.
        - Write dates the way they are written below. Never rewrite one as digits.
        - Start from this projekt's own subject. Do not open with a formula that would fit any
          projekt ("In dem Projekt geht es um", "Bei diesem Projekt handelt es sich um", "This
          project is about"), and do not follow a fixed order of sentences: another projekt's
          introduction must not read like this one with the nouns swapped.
        - Whole sentences, a few of them at most. No bullet points, no headings, no list of
          settings, no link — the message this goes into carries the link already.
        - No greeting, no question to the citizen, and no invitation to take part: that question is
          asked by the message that follows this one.
      TEXT
    end

    # The citizen's own language rather than the language of the facts. The
    # labels below are English scaffolding and the page they describe is in
    # whatever the portal writes, so "the language you are given" would be two
    # answers at once — the chat follows the reader, as every other prompt here
    # does.
    def output_language
      ::Ai::OutputLanguage.chat_name_for(I18n.locale)
    end

    def output_schema
      {
        type: "object",
        properties: {
          summary: {
            type: "string",
            description: "The introduction to the projekt, at most #{target_length} characters, " \
                         "in #{output_language}."
          }
        },
        required: %w[summary],
        additionalProperties: false
      }
    end

    # Handed over as labelled lines rather than as JSON: the model reads it once
    # and never has to address a field by name, and a blank section is simply
    # absent instead of present and empty.
    def context
      return @context if defined?(@context)

      @context = [
        page_section,
        phases_section,
        polls_section,
        events_section,
        milestones_section,
        results_section
      ].compact_blank.join("\n\n").presence
    end

    def page_section
      return if @projekt.page.blank?

      lines = [
        labelled("Title", ::Whatsapp::ProjektLink.title(@projekt)),
        labelled("Subtitle", @projekt.page.subtitle),
        labelled("Page content", page_text)
      ].compact_blank

      lines.join("\n").presence
    end

    # Read through Projekt#page_content rather than off the page, because a
    # projekt in content-block mode leaves pages.content empty — reading the
    # column directly described every modern projekt as having nothing to say.
    # Content blocks also carry {{projekt_map}}-style placeholders the page
    # expands at render time, which left in are read as text and repeated.
    def page_text
      ::Whatsapp.plain_text(
        @projekt.page_content.to_s.gsub(/\{\{.*?\}\}/, " "), length: PAGE_LENGTH
      ).presence
    end

    def phases_section
      rows = projekt_phases.map do |projekt_phase|
        [
          projekt_phase.title,
          date_range_phrase(projekt_phase),
          ::Whatsapp::EligiblePhasesQuery.eligible?(projekt_phase) ? "open for submissions" : nil
        ].compact_blank.join(", ")
      end

      section("Phases", rows)
    end

    def date_range_phrase(projekt_phase)
      ends_on = ::Whatsapp::DatePhrase.absolute(projekt_phase.end_date)

      return if ends_on.blank?

      "ends #{ends_on} (#{::Whatsapp::DatePhrase.relative(projekt_phase.end_date)})"
    end

    def polls_section
      rows = ::Whatsapp::OpenPollsQuery.call(projekt: @projekt).first(MAX_CONTEXT_ROWS).map do |poll|
        [poll.name, labelled_date("ends", poll.ends_at)].compact_blank.join(", ")
      end

      section("Votes running now", rows)
    end

    def events_section
      rows = ::Whatsapp::UpcomingEventsQuery.call(projekt: @projekt)
        .first(MAX_CONTEXT_ROWS).map do |event|
          [
            event.title,
            ::Whatsapp::DatePhrase.absolute_with_time(event.datetime),
            event.location.presence
          ].compact_blank.join(", ")
        end

      section("Upcoming events", rows)
    end

    def milestones_section
      rows = ::Whatsapp::PublishedMilestonesQuery.call(projekt: @projekt)
        .first(MAX_CONTEXT_ROWS).map do |milestone|
          [
            milestone.title.presence || ::Whatsapp.plain_text(milestone.description, length: 200),
            labelled_date("on", milestone.publication_date)
          ].compact_blank.join(", ")
        end

      section("What has happened so far", rows)
    end

    def results_section
      rows = ::Whatsapp::PublishedResultsQuery.call(projekt: @projekt)
        .first(MAX_CONTEXT_ROWS).map do |projekt_phase|
          [
            projekt_phase.title,
            labelled_date("ended on", projekt_phase.end_date)
          ].compact_blank.join(", ")
        end

      section("Published results", rows)
    end

    # Read once and shared: the fingerprint asks how the phases stand before the
    # context asks what they are called.
    def projekt_phases
      @projekt_phases ||= ::Whatsapp::ProjektPhasesQuery.call(projekt: @projekt)
    end

    def section(label, rows)
      return if rows.compact_blank.empty?

      ["#{label}:", *rows.compact_blank.map { |row| "- #{row}" }].join("\n")
    end

    def labelled(label, value)
      return if value.blank?

      "#{label}: #{value.to_s.squish}"
    end

    def labelled_date(label, value)
      absolute = ::Whatsapp::DatePhrase.absolute(value)

      return if absolute.blank?

      "#{label} #{absolute}"
    end
end
