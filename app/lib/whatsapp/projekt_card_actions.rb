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

  module_function

  # The card's entries, most useful first: every open phase's own action, then the
  # one entry that opens what is already there. Ordered by the phases' own
  # given_order, which is the order the portal puts them in on the page.
  #
  # Every open phase keeps its entry, phases of the same kind included. They used to
  # be deduplicated by the label — the one thing a button shows — so a projekt running
  # four voting phases at once offered "Jetzt abstimmen" once and the other three
  # could not be voted in from the chat at all. What tells them apart is the phase's
  # own name and closing date, which travel as the entry's description and which only
  # the list form renders; list_required? is what keeps colliding titles off buttons.
  #
  # Cut to what a list holds, because past that the sender truncates rows away
  # silently. The phases are what the card is for, so the entry that gives is the
  # trailing one — the way to the existing contributions, which the projekt link also
  # reaches.
  # `user` is who the card is being sent to, and only the wording of a button depends on
  # it: a phase they have already taken part in keeps its row and its place, because the
  # row is how they reach what they did there and dropping it would leave the card
  # quietly shorter for the people who have used it most. Left out, every label is the
  # one everybody used to get — which is what a caller with nobody to send the card to
  # should show.
  def call(projekt, user: nil)
    phases = actionable_phases(projekt)
    facts = ::Whatsapp::ProjektCard.phase_facts(phases)
    voted_ids = ::Whatsapp::BallotParticipation.completed_phase_ids(
      projekt_phases: markable(phases), user: user
    )
    entries =
      (phases.map { |phase| action_entry(phase, facts[phase.id], voted_ids) } +
        [contributions_entry(phases, facts)])
        .compact
        .first(::Whatsapp::MAX_OFFERED_LIST_ROWS)

    log_entries_reading_alike(projekt, entries)

    entries
  end

  # Whether these entries have to arrive behind the list picker rather than as reply
  # buttons. Two reasons now, where it used to be only the first: more entries than a
  # message holds buttons for, or two entries whose titles read alike. A reply button
  # carries a title and nothing else — WhatsappApi::Resources::Messages drops the
  # description a list row shows — so entries reading alike are indistinguishable
  # there, and the twenty characters a title holds leave no room to work the phase name
  # in. Titles collide across phase types as well as within one: proposal_phase and
  # budget_phase are both labelled "Vorschlag erstellen".
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

  def action_entry(projekt_phase, phase_facts, voted_ids)
    entry(
      action: action_for(projekt_phase),
      projekt_phase: projekt_phase,
      title: card_label(projekt_phase, voted_ids),
      description: phase_description(phase_facts)
    )
  end

  # The phases a mark is even possible for, which is the whole of what the batch above
  # is asked about: a type nobody wrote a voted wording for has nothing to say however
  # much the citizen has done in it, and including it would put a ballot lookup behind
  # every proposal and formular row of every card.
  def markable(phases)
    phases.select { |projekt_phase| scoped_label(VOTED_LABEL_SCOPE, projekt_phase).present? }
  end

  # What tells two rows carrying the same action apart: the phase's name and its
  # closing date. The date as well as the name because the name alone need not
  # differ — a portal running four voting phases may have left two of the ballots
  # named alike — and two rows reading alike in every field are a list WhatsApp
  # refuses outright, where the same two dated apart send and read fine. Written
  # through DatePhrase like every other date the bot shows, so it cannot arrive as a
  # tappable phone number.
  def phase_description(phase_facts)
    return if phase_facts.blank?

    [phase_facts.name, ::Whatsapp::DatePhrase.absolute(phase_facts.ends_on)]
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
  # characters WhatsApp allows a button title are guaranteed rather than truncated
  # mid-word; #truncated is the backstop for a translation that outgrows them.
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
  # time and have no page to batch over. The card asks #card_label instead: it knows
  # which of its phases are marked before it labels any of them.
  def label_for(projekt_phase, user: nil)
    return action_label(projekt_phase) if !voted?(projekt_phase, user)

    marked_label(projekt_phase)
  end

  def card_label(projekt_phase, voted_ids)
    return action_label(projekt_phase) if !voted_ids.include?(projekt_phase.id)

    marked_label(projekt_phase)
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
