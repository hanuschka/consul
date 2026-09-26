module Whatsapp::ProjektCardActions
  # What the projekt card offers, one entry per open phase, worded as the action
  # itself. The card used to end on a single pill that only opened a further step
  # where the citizen picked what to do — a selection step whose whole content the
  # card already knew, because the phases are what it was built from.
  #
  # Which phase types have an action, keyed by the phase's own #name — and the
  # register is the locale copy itself rather than a list beside it. A phase type
  # contributes an action exactly when there is a word to put on its button, so the
  # two cannot fall out of step: a list and a set of keys maintained separately
  # answer a missing key with a blank label, which drops the phase's button silently
  # and with no error anywhere. A phase type nobody wrote a label for contributes
  # nothing, which is what keeps a newsfeed or a milestone phase off the card — they
  # are open, but there is nothing in them for the citizen to do.
  ACTION_LABEL_SCOPE = "whatsapp.bot.buttons.phase_action".freeze

  # The same buttons worded for a citizen who has already taken part, and a scope of its
  # own rather than keys inside the one above: that scope's keys ARE the register of
  # which phase types get an action, so a second key per type there would invent a phase
  # type and put a row on the card for it. Only the types listed here can be marked; a
  # type with no entry keeps its ordinary label, which is the right answer for every
  # phase where taking part is not a thing that finishes.
  VOTED_LABEL_SCOPE = "whatsapp.bot.buttons.phase_action_voted".freeze

  # The wording that puts the ballot's own name on the row of a citizen who has answered
  # it. A key of its own and deliberately not one inside VOTED_LABEL_SCOPE, whose keys are
  # the register above: a key more there would invent a phase type and put a row on the
  # card for it.
  VOTED_TITLE_KEY = "whatsapp.bot.buttons.phase_action_voted_title".freeze

  # The two lines of a row, worked out as one thing because they are one decision. A phase
  # has two identities on a card — the action it offers and the name it goes by — and
  # whichever of them the title takes, the line underneath carries the other, so nothing is
  # said twice and nothing that tells two rows apart goes unsaid.
  #
  # `named` records which way round that came out, because #told_apart's whole remedy for a
  # repeated title is to put the phase's name there: a row whose title is already the name
  # has nothing left to be substituted, and rewriting it anyway would strip the mark and
  # the word underneath while leaving the two rows just as alike as before.
  RowText = Struct.new(:title, :note, :named, keyword_init: true)

  module_function

  # The card's entries, most useful first: every open phase's own action, then the
  # one entry that opens what is already there. Ordered by the phases' own
  # given_order, which is the order the portal puts them in on the page.
  #
  # Every open phase keeps its entry, phases of the same kind included. They used to
  # be deduplicated by the label — the one thing a button shows — so a projekt running
  # four voting phases at once offered "Jetzt abstimmen" once and the other three
  # could not be voted in from the chat at all. What tells them apart is now the row's
  # own title, worked out by #row_texts over the whole set at once: a title that would
  # have repeated is replaced by the phase's own name before any row is built from it.
  #
  # Cut to what a list holds, because past that the sender truncates rows away
  # silently. The entry that gives is a phase's, never the trailing one: the way to the
  # existing contributions used to be what fell off once the phases alone filled the
  # card, so a projekt with ten running phases lost the one row that opened what was
  # already in it. Now a row is kept for it whenever there is one to show, and the
  # phases share what is left. A cut that still costs a running phase is said out loud
  # by #log_phases_cut, where it used to happen with nothing anywhere naming it.
  # `user` is who the card is being sent to, and only the wording of a button depends on
  # it: a phase they have already taken part in keeps its row and its place, because the
  # row is how they reach what they did there and dropping it would leave the card
  # quietly shorter for the people who have used it most. Left out, every label is the
  # one everybody used to get — which is what a caller with nobody to send the card to
  # should show.
  def call(projekt, user: nil)
    phases = actionable_phases(projekt)
    facts = ::Whatsapp::ProjektCard.phase_facts(phases)
    contributions = contributions_entry(phases, facts)
    kept = phases.first(phase_row_budget(contributions))
    voted_ids = ::Whatsapp::BallotParticipation.completed_phase_ids(
      projekt_phases: markable(kept), user: user
    )
    texts = row_texts(kept, facts, voted_ids)
    entries =
      (kept.map { |phase| action_entry(phase, facts[phase.id], texts[phase.id]) } +
        [contributions]).compact

    log_phases_cut(projekt, phases, kept)
    log_entries_reading_alike(projekt, entries)

    entries
  end

  # How many phase rows the card has room for once the contributions row, when there
  # is one, has taken its place.
  def phase_row_budget(contributions)
    ::Whatsapp::MAX_OFFERED_LIST_ROWS - [contributions].compact.size
  end

  # Whether these entries have to arrive behind the list picker rather than as reply
  # buttons. Two reasons now, where it used to be only the first: more entries than a
  # message holds buttons for, or two entries whose titles read alike. A reply button
  # carries a title and nothing else — WhatsappApi::Resources::Messages drops the
  # description a list row shows — so entries reading alike are indistinguishable there.
  # #row_texts settles most of that before this is asked, by naming a repeated title after
  # its own phase; what is left for the second reason is the collision it cannot resolve,
  # which is two phases carrying the same name as well as the same action.
  def list_required?(entries)
    titles = entries.map { |entry| entry[:title] }

    !::Whatsapp.buttons?(titles.size) || titles.uniq.size != titles.size
  end

  def actionable_phases(projekt)
    ::Whatsapp::ProjektPhasesQuery.new(projekt: projekt).call.select do |projekt_phase|
      actionable_phase_names.include?(projekt_phase.name.to_s) && projekt_phase.current?
    end
  end

  # Read at the portal's own locale rather than at whichever is current, the way
  # Whatsapp::Send reads the start-over pill: these are the fixed copy, and a set of
  # types that changed with the locale would offer different actions to different
  # people. Only some locales carry the whole set — en falls back to de in production
  # and nowhere else — so which types have an action has to be one answer.
  def actionable_phase_names
    I18n.t(ACTION_LABEL_SCOPE, locale: ::Whatsapp.default_locale, default: {}).keys.map(&:to_s)
  end

  # Which pill the phase gets, and the split is EligiblePhasesQuery's rather than a
  # list of its own: a phase the bot can take a submission into enters the drafting
  # flow on the tap, and every other one is acted on where the action actually lives,
  # which is the portal. That also covers a proposal phase whose portal has switched
  # the bot off as a submission channel — still open on the website, so still worth
  # naming, but as a link.
  def action_for(projekt_phase)
    return :idea_start if ::Whatsapp::EligiblePhasesQuery.eligible?(projekt_phase)

    :phase_open
  end

  def action_entry(projekt_phase, phase_facts, row_text)
    entry(
      action: action_for(projekt_phase),
      projekt_phase: projekt_phase,
      title: row_text.title,
      description: phase_description(phase_facts, row_text.note)
    )
  end

  # The phases a mark is even possible for, which is the whole of what the batch above
  # is asked about: a type nobody wrote a voted wording for has nothing to say however
  # much the citizen has done in it, and including it would put a ballot lookup behind
  # every proposal and formular row of every card.
  def markable(phases)
    phases.select { |projekt_phase| scoped_label(VOTED_LABEL_SCOPE, projekt_phase).present? }
  end

  # The line under the title: whichever of the phase's two identities the title left for
  # it, and the closing date. The date as well, because that half need not differ on its
  # own — a portal running four voting phases may have left two of the ballots named
  # alike — and two rows reading alike in every field are a list WhatsApp refuses
  # outright, where the same two dated apart send and read fine. Written through
  # DatePhrase like every other date the bot shows, so it cannot arrive as a tappable
  # phone number.
  def phase_description(phase_facts, note)
    return if phase_facts.blank?

    [note, ::Whatsapp::DatePhrase.absolute(phase_facts.ends_on)]
      .compact_blank
      .join(" · ")
      .presence
  end

  # One entry rather than one per phase: the ticket asks for the phases' actions and
  # a further way to what is already in the projekt, and a second row per phase would
  # double a list whose rows are meant to read as the things there are to do. The
  # leading phase is the one it points at, which is the phase whose action heads the
  # card.
  def contributions_entry(phases, facts)
    projekt_phase = phases.find do |candidate|
      ::Whatsapp::PhaseContributionsQuery.shows_for?(candidate)
    end

    return if projekt_phase.blank?

    entry(
      action: :phase_contributions,
      projekt_phase: projekt_phase,
      title: I18n.t(
        "whatsapp.bot.buttons.phase_contributions", locale: ::Whatsapp.default_locale
      ),
      description: facts[projekt_phase.id]&.name
    )
  end

  # Labelled from the locale copy keyed by the phase type rather than from the
  # phase's own title. The title is a name — "Ideen", "Bürgerhaushalt" — where a
  # button has to be an instruction, and a portal that renames a phase would
  # otherwise rename the action with it. It is also the only way the twenty
  # characters WhatsApp allows a button title are guaranteed rather than spent down
  # to an ellipsis; #truncated is the backstop for a translation that outgrows them.
  #
  # A citizen who has already voted is told so on the button itself, before they tap it.
  # The pill used to read "Jetzt abstimmen" whatever they had already done, so the only
  # way to find out a vote was closed to them was to tap it — and the reply to that tap
  # said nothing about it either.
  #
  # The voted wording is an override and never a replacement: a phase type nobody wrote
  # one for, or a citizen who has not finished the ballot, falls through to the ordinary
  # label, and a blank there still drops the row the way it always did.
  # One phase at a time, for the assistant's own pills, which arrive one record at a
  # time and have no page to batch over. They keep the plain marked wording rather than
  # the card's named one: a pill is offered for the phase under discussion, so there is
  # no second row beside it to be confused with, and the assistant's pills can still be
  # sent as buttons, where the twenty characters leave no room for a name. The card asks
  # #row_texts instead: it knows all of its phases before it words any of them.
  def label_for(projekt_phase, user: nil)
    return action_label(projekt_phase) if !voted?(projekt_phase, user)

    marked_label(projekt_phase)
  end

  # Every phase's two lines, worked out over the whole set at once. Whether a title says
  # enough to tell its row apart is a property of the set and not of the phase: "Jetzt
  # abstimmen" names the action on a card with one open vote and names nothing on a card
  # with four. Cut to length last, once the wording is settled, so the budget is spent on
  # the words that survived the comparison rather than on the ones about to be replaced.
  def row_texts(phases, facts, voted_ids)
    written = phases.index_by(&:id).transform_values do |projekt_phase|
      written_row(projekt_phase, facts[projekt_phase.id], voted_ids)
    end
    length = title_length(written.values.count { |row| row.title.present? })

    told_apart(written, facts).transform_values do |row|
      RowText.new(
        title: ::Whatsapp::AssistantActions.truncated(row.title, length: length),
        note: row.note,
        named: row.named
      )
    end
  end

  # What a row says before anything is done about its neighbours.
  def written_row(projekt_phase, phase_facts, voted_ids)
    if voted_ids.include?(projekt_phase.id)
      marked_row(projekt_phase, phase_facts)
    else
      unmarked_row(projekt_phase, phase_facts&.name)
    end
  end

  def unmarked_row(projekt_phase, name)
    RowText.new(
      title: scoped_label(ACTION_LABEL_SCOPE, projekt_phase), note: name, named: false
    )
  end

  # A vote this citizen has already answered, named rather than merely marked. The row
  # used to read "Bereits abgestimmt" and nothing else, so a projekt running four ballots
  # put four rows on the card that a citizen could not choose between — told apart only by
  # the line underneath, which a reply button does not render at all. The name goes on top
  # and the word moves down, where there is room for it and where it is no longer the only
  # thing the row says.
  #
  # Both fallbacks keep the row rather than losing it: a phase type nobody wrote a voted
  # wording for falls through to its ordinary action, and a phase with no name to put in
  # the title — or a portal locale that predates the named wording — keeps the word there.
  def marked_row(projekt_phase, phase_facts)
    voted_word = scoped_label(VOTED_LABEL_SCOPE, projekt_phase)
    name = phase_facts&.name
    title = voted_title(name)

    if voted_word.blank?
      unmarked_row(projekt_phase, name)
    elsif title.blank?
      RowText.new(title: voted_word, note: name, named: false)
    else
      RowText.new(title: title, note: voted_word, named: true)
    end
  end

  # Read at the portal's own locale like every other fixed word on the card, and with no
  # default: a locale that does not carry the key answers nil, which #marked_row reads as
  # the instruction to keep the wording the row had before rather than putting a raw
  # translation-missing string on a title.
  def voted_title(name)
    return if name.blank?

    I18n.t(VOTED_TITLE_KEY, name: name, locale: ::Whatsapp.default_locale, default: nil)
  end

  # Titles that repeat replaced by the thing that differs, which is the phase's own name,
  # with the word they gave up moved to the line underneath. The verb is what yields — a
  # proposal phase and a budget phase both offering "Vorschlag erstellen" become their two
  # names — because a citizen who cannot tell which row is which cannot use either of
  # them, and because a list carrying two identical rows is one WhatsApp refuses outright,
  # which costs the whole card rather than the one row.
  #
  # A phase whose title is already its name, or that has no name to offer, keeps what it
  # has: there is nothing there left to tell it apart with, and the date on the line below
  # is the last thing that can. That case is two concurrent ballots a portal named the
  # same, which #log_entries_reading_alike is there to say out loud.
  def told_apart(written, facts)
    repeated = written
      .values
      .map(&:title)
      .compact_blank
      .tally
      .select { |_, count| count > 1 }
      .keys

    written.to_h do |phase_id, row|
      name = facts[phase_id]&.name

      if repeated.exclude?(row.title) || row.named || name.blank?
        [phase_id, row]
      else
        [phase_id, RowText.new(title: name, note: row.title, named: true)]
      end
    end
  end

  # The characters a title may spend. A set of rows is sent as reply buttons or behind the
  # list picker depending only on how many there are, so a title has to be written to the
  # button's smaller budget unless this card cannot be sent as buttons at all — only then
  # are the four extra characters a list row allows safe to spend on it.
  #
  # Counted over the labelled phases alone rather than over the finished entries: the
  # trailing contributions row only ever makes a card longer, so leaving it out can
  # understate the count but never overstate it, and understating it only costs four
  # characters where overstating it would ship a title WhatsApp cuts mid-word.
  def title_length(labelled_count)
    if ::Whatsapp.buttons?(labelled_count)
      ::Whatsapp::AssistantActions::MAX_LABEL_LENGTH
    else
      ::Whatsapp::AssistantActions::MAX_ROW_TITLE_LENGTH
    end
  end

  # The voted wording where the phase type has one and the ordinary label where it has
  # none, so a marked phase nobody wrote a word for keeps its row rather than losing it
  # — a blank title is what #entry drops.
  def marked_label(projekt_phase)
    truncated_label(VOTED_LABEL_SCOPE, projekt_phase).presence ||
      action_label(projekt_phase)
  end

  def action_label(projekt_phase)
    truncated_label(ACTION_LABEL_SCOPE, projekt_phase)
  end

  # The wording is looked up before the citizen's answers are, which is the cheap half
  # first: a phase type with no voted wording has nothing to say however much the
  # citizen has done in it, and asking anyway would put a ballot lookup and a walk of
  # its questions behind every pill the assistant offers.
  def voted?(projekt_phase, user)
    return false if user.blank?
    return false if scoped_label(VOTED_LABEL_SCOPE, projekt_phase).blank?

    ::Whatsapp::BallotParticipation.completed?(projekt_phase: projekt_phase, user: user)
  end

  def truncated_label(scope, projekt_phase)
    ::Whatsapp::AssistantActions.truncated(scoped_label(scope, projekt_phase))
  end

  def scoped_label(scope, projekt_phase)
    I18n.t(
      "#{scope}.#{projekt_phase.name}", locale: ::Whatsapp.default_locale, default: nil
    )
  end

  # The description travels on every entry and is read by whichever form the card
  # takes: WhatsappApi::Resources::Messages puts it under the row of a list and
  # ignores it on a reply button, which holds a title and nothing else.
  # A row is told from the one above it by its title and, in list form, by the line
  # under it, so two rows alike in both are two the citizen cannot choose between —
  # and a list carrying them is one WhatsApp refuses outright, which loses the whole
  # card rather than one row of it.
  #
  # Nothing here can prevent it: it is a portal that named two concurrent phases of
  # one kind the same thing, with neither carrying a dated ballot to tell them apart.
  # What is left is to say so, because the send fails at Meta's edge with nothing
  # there naming the projekt whose phases caused it.
  # A running phase the card had no row for. The query already puts the running phases
  # ahead of the cap, so reaching this means the projekt runs more actionable phases
  # at once than a list can hold — which nothing here can fix, and which used to pass
  # without a trace.
  def log_phases_cut(projekt, phases, kept)
    dropped = phases.drop(kept.size)

    return if dropped.blank?

    Rails.logger.warn(
      "[Whatsapp] projekt #{projekt.id} card holds #{kept.size} of #{phases.size} running " \
      "phases, dropped phase ids: #{dropped.map(&:id).join(", ")}"
    )
  end

  def log_entries_reading_alike(projekt, entries)
    alike = entries
      .group_by { |entry| [entry[:title], entry[:description]] }
      .select { |_, group| group.size > 1 }

    return if alike.blank?

    rows = alike.keys.map { |title, description| [title, description].compact_blank.join(" · ") }

    Rails.logger.warn(
      "[Whatsapp] projekt #{projekt.id} card carries rows reading alike, which WhatsApp may " \
      "refuse: #{rows.join(", ")}"
    )
  end

  def entry(action:, projekt_phase:, title:, description:)
    return if title.blank?

    {
      id: ::Whatsapp::FlowActions.id_for(action: action, param: projekt_phase.id),
      title: title,
      description: description
    }
  end
end
