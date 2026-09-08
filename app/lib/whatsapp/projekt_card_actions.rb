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

  module_function

  # The card's entries, most useful first: every open phase's own action, then the
  # one entry that opens what is already there. Ordered by the phases' own
  # given_order, which is the order the portal puts them in on the page.
  # Deduplicated by the label, which is the one thing the citizen reads: a projekt
  # running two proposal phases at once would otherwise offer "Vorschlag erstellen"
  # twice, with nothing on either button to say which of them it leads into. The
  # first survives, so the phase the portal orders first is the one the action goes
  # to — and the entry keeps the phase's own name as its description, which the list
  # form shows and the button form has no room for.
  def call(projekt)
    phases = actionable_phases(projekt)

    (phases.map { |projekt_phase| action_entry(projekt_phase) } +
      [contributions_entry(phases)]).compact.uniq { |entry| entry[:title] }
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

  def action_entry(projekt_phase)
    entry(
      action: action_for(projekt_phase),
      projekt_phase: projekt_phase,
      title: label_for(projekt_phase)
    )
  end

  # One entry rather than one per phase: the ticket asks for the phases' actions and
  # a further way to what is already in the projekt, and a second row per phase would
  # double a list whose rows are meant to read as the things there are to do. The
  # leading phase is the one it points at, which is the phase whose action heads the
  # card.
  def contributions_entry(phases)
    projekt_phase = phases.find do |candidate|
      ::Whatsapp::PhaseContributionsQuery.shows_for?(candidate)
    end

    return if projekt_phase.blank?

    entry(
      action: :phase_contributions,
      projekt_phase: projekt_phase,
      title: I18n.t(
        "whatsapp.bot.buttons.phase_contributions", locale: ::Whatsapp.default_locale
      )
    )
  end

  # Labelled from the locale copy keyed by the phase type rather than from the
  # phase's own title. The title is a name — "Ideen", "Bürgerhaushalt" — where a
  # button has to be an instruction, and a portal that renames a phase would
  # otherwise rename the action with it. It is also the only way the twenty
  # characters WhatsApp allows a button title are guaranteed rather than truncated
  # mid-word; #truncated is the backstop for a translation that outgrows them.
  def label_for(projekt_phase)
    ::Whatsapp::AssistantActions.truncated(
      I18n.t(
        "#{ACTION_LABEL_SCOPE}.#{projekt_phase.name}",
        locale: ::Whatsapp.default_locale,
        default: nil
      )
    )
  end

  # The description travels on every entry and is read by whichever form the card
  # takes: WhatsappApi::Resources::Messages puts it under the row of a list and
  # ignores it on a reply button, which holds a title and nothing else.
  def entry(action:, projekt_phase:, title:)
    return if title.blank?

    {
      id: ::Whatsapp::FlowActions.id_for(action: action, param: projekt_phase.id),
      title: title,
      description: projekt_phase.title
    }
  end
end
