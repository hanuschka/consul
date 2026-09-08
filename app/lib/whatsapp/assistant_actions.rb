module Whatsapp::AssistantActions
  # Which pills the assistant may put under a reply, and nothing about what they
  # are called: the label is the model's sentence, the same way the reply above it
  # is. What stays bounded is the id, because WhatsApp returns the *id* to the
  # webhook and the inbound side is what turns that id back into an action. An id the
  # model invented has nothing behind it — the citizen taps and nothing happens, with
  # no error anywhere — so the set of ids is closed while the words on them are not.
  #
  # The set is every id the dispatcher handles, irreversible ones included. What
  # keeps that safe is not an allowlist here: it is that the dispatcher
  # re-validates on the tap — the account, the record, the phase still being open
  # — so a pill offered wrongly still cannot act wrongly.
  HANDLED_ACTIONS = ::Whatsapp::FlowActions::ACTIONS

  # WhatsApp truncates a button title past this, mid-word, with no ellipsis, so a
  # 21-character label ships as nonsense rather than as a slightly long label.
  MAX_LABEL_LENGTH = 20

  # The actions whose consequence cannot be taken back from a chat. Their labels
  # are the model's like every other, but the offer is recorded as its own event:
  # a pill that publishes a contribution has to be findable afterwards, and "the
  # assistant offered this" is not otherwise distinguishable from "the citizen
  # asked for it".
  #
  # Four, and supporting is not among them: a support can be taken back, on the
  # projekt page and now from the chat as well, so the ceremony that made it cost
  # two taps was protecting against a consequence that does not exist. What is left
  # here has no undo anywhere — a published contribution, a submitted one, a comment
  # on a public page, a severed account link.
  IRREVERSIBLE_ACTIONS = %i[draft_publish submit_final comment_post unlink_confirm].freeze

  # The one pill whose words are not the model's. Every other label is a sentence it
  # wrote, checked for length and nothing else, because the dispatcher re-resolves the
  # id on the tap and a poor label costs a badly-worded button.
  #
  # The support toggle is the exception because the same id does opposite things: it
  # gives support or takes it back depending on the vote as it stands when the tap
  # arrives. A label the model wrote a message earlier can therefore say the precise
  # opposite of what tapping it does, and the citizen has no way to tell. Read from
  # the vote instead, and the model's own words for this one are discarded rather
  # than preferred.
  FORCED_LABEL_ACTIONS = %i[support_toggle].freeze

  module_function

  # Every id the assistant may name, for the tool descriptions that list them. The
  # recovery ids belong here too: they are offerable like any other, and without
  # them in the list the model has no way to put a way out beside a question — which
  # is exactly the button a citizen part-way through a submission needs most.
  #
  # The parameterised ones are listed by shape rather than enumerated: the records
  # behind them arrive from whichever tool the model just called, and enumerating a
  # portal's projekts here would be the whole portal in every prompt.
  # The retired and bot-only ids are subtracted from both lists rather than from
  # ACTIONS: they are still dispatched, so the vocabulary the assistant reads is the
  # only place they may be absent from.
  def offerable_action_names
    (
      (HANDLED_ACTIONS - ::Whatsapp::FlowActions::PARAMETERISED_ACTIONS -
        ::Whatsapp::FlowActions.unofferable) +
        ::Whatsapp::Send::RECOVERY_ACTION_IDS.keys
    ).map(&:to_s)
  end

  def parameterised_action_names
    (
      ::Whatsapp::FlowActions::PARAMETERISED_ACTIONS - ::Whatsapp::FlowActions.unofferable
    ).map(&:to_s)
  end

  # One tappable button from the action id and the label the model wrote, or nil
  # when that is not something it may offer. Nil rather than an exception on
  # purpose: one unusable pill in a set of three should cost that pill, not the
  # reply.
  def button(spec:, label:, conversation:)
    action, param = parse(spec)

    return dropped(spec, conversation, :unparseable) if action.blank?
    return dropped(spec, conversation, :unknown_action) if !::Whatsapp::FlowActions.known?(action)
    return dropped(spec, conversation, :unofferable) if ::Whatsapp::FlowActions.unofferable?(action)
    return dropped(spec, conversation, :unknown_scope) if !known_scope?(action, param)
    return dropped(spec, conversation, :nothing_to_tell) if !tells_more?(action, param)

    title = title_for(action: action, param: param, label: label, conversation: conversation)

    return dropped(spec, conversation, :unlabelled) if title.blank?

    record_irreversible_offer(action, conversation)

    { id: ::Whatsapp::FlowActions.id_for(action: action, param: param), title: title }
  end

  # One of the two parameters checked before the label rather than through it —
  # `view_projekt` below is the other, for a different reason. Most parameterised
  # pills point at a record, and a label the model wrote is accepted without reading
  # that record because the dispatcher resolves it again on the tap. `show_more`'s
  # parameter is a scope name instead: nothing resolves it later, so an invented one
  # is a pill that is tapped and does nothing.
  def known_scope?(action, param)
    return true if action != :show_more

    ::Whatsapp::FlowActions::MORE_SCOPES.include?(param.to_s)
  end

  # The other one, and the one pill that does read its record before the label: a
  # "view projekt" on a projekt whose card already says everything would deliver
  # that card again, so it is not offered — the same rule the card and the
  # notification follow-ups apply. A projekt that does not exist has nothing to
  # tell either.
  def tells_more?(action, param)
    return true if action != :view_projekt

    projekt = ::Projekt.find_by(id: param.to_i)

    return false if projekt.blank?

    ::Whatsapp::ProjektCard.tells_more?(projekt)
  end

  # A recovery pill keeps its own id namespace — the inbound side reads those
  # before the catalog's, and that ordering is what lets a "cancel" beside two
  # ordinary pills be understood without anything else knowing about it.
  def recovery_button(spec:, label:)
    action, = parse(spec)
    recovery_id = ::Whatsapp::Send::RECOVERY_ACTION_IDS[action]

    return if recovery_id.blank?

    title = truncated(label)

    return if title.blank?

    { id: recovery_id, title: title }
  end

  # The model's own words, cut on a word boundary. WhatsApp's own truncation is
  # mid-word and silent, so a label that is one character too long arrives as a
  # fragment; cutting it here at least ends on something readable.
  #
  # Falls back to the record's own name for a parameterised pill the model left
  # unlabelled — a projekt's title as the portal writes it is better than a
  # paraphrase, and it is also what proves the record exists.
  def title_for(action:, param:, label:, conversation:)
    if FORCED_LABEL_ACTIONS.include?(action)
      return truncated(record_label(action: action, param: param, conversation: conversation))
    end

    written = truncated(label)

    return written if written.present?
    return if !::Whatsapp::FlowActions.parameterised?(action)

    truncated(record_label(action: action, param: param, conversation: conversation))
  end

  def truncated(label)
    text = label.to_s.squish

    return if text.blank?

    text.truncate(MAX_LABEL_LENGTH, separator: " ", omission: "")
  end

  # The label of a translated fixed line, as it will actually arrive. Preferring the
  # translation, but not at the price of arriving cut mid-word.
  #
  # #truncated finds a word boundary only when there is a space inside the limit.
  # A single compound longer than it has none, and Rails falls back to a hard cut —
  # so "Benachrichtigungseinstellungen" ships as "Benachrichtigungsein", which no
  # cut can fix because no cut of it fits. German and Turkish generate exactly those.
  #
  # Where the written copy does fit whole, that is the readable answer: a label in
  # the portal's own language beats a fragment in the citizen's, and it is the same
  # trade BotCopyService already makes whenever a translation cannot be had. A
  # translation cut on a real word boundary is not a fragment and is kept.
  # Blank is answered by the written copy rather than by nil: BotCopyService cannot
  # hand back a blank line — a mismatched count falls the whole message back to the
  # copy as written — but a blank title is the one value WhatsApp refuses the message
  # over, so this never returns one while the copy behind it has words.
  def fitting_label(translated:, original:)
    text = translated.to_s.squish
    written = original.to_s.squish
    cut = truncated(text)

    return truncated(written) if cut.blank?
    return cut if cut == text || ended_on_boundary?(text, cut)
    return cut if truncated(written) != written

    written
  end

  # Whether the cut fell between words rather than inside one. Asked of the
  # character the cut stopped before, not of the cut's own contents: #truncated
  # consumes the separator, so a boundary cut that leaves one short word — "Ab" out
  # of "Ab cdefghij…" — holds no space and would read as a fragment while being
  # nothing of the kind.
  def ended_on_boundary?(text, cut)
    text[cut.length] == " "
  end

  # The label read off the thing the pill points at. A projekt that does not
  # exist, a taxonomy option the phase does not offer and a notification type
  # nobody has heard of all come back blank, and a blank pill is not offered —
  # which is the same check that keeps a stale record id from being sent as a
  # button in the first place.
  def record_label(action:, param:, conversation:)
    return if param.blank?

    case action
    when :view_projekt then projekt_label(param)
    when :view_contribution then contribution_label(param)
    when :idea_start then phase_projekt_label(param)
    when :phase_open then phase_action_label(param)
    when :phase_contributions then I18n.t("whatsapp.bot.buttons.phase_contributions")
    when :support then proposal_label(param)
    when :support_toggle then support_toggle_label(param, conversation)
    when :category
      taxonomy_label(::Whatsapp::DraftTaxonomy.category(conversation.projekt_phase), param)
    when :sentiment
      taxonomy_label(::Whatsapp::DraftTaxonomy.sentiment(conversation.projekt_phase), param)
    when :notify_toggle then notification_label(param)
    when :discover_category then browse_category_label(param)
    when :show_more then I18n.t("whatsapp.bot.buttons.show_more")
    end
  end

  def projekt_label(param)
    projekt = ::Projekt.find_by(id: param.to_i)

    return if projekt.blank?

    ::Whatsapp::ProjektLink.title(projekt)
  end

  # The same wording the projekt card puts on the phase, so the assistant offering a
  # phase without labelling it says what the card would have said. Blank for a phase
  # type the card has no action for, which drops the pill: an unlabelled button
  # pointing at a phase nothing can be done in is a tap that leads nowhere.
  def phase_action_label(param)
    projekt_phase = ::ProjektPhase.find_by(id: param.to_i)

    return if projekt_phase.blank?

    ::Whatsapp::ProjektCardActions.label_for(projekt_phase)
  end

  # The line under a row, for the rows whose twenty-character label cannot say which
  # record they point at. The phase pills are named after what tapping them does —
  # "Vorschlag erstellen", "Beiträge ansehen" — so every phase on the portal reads
  # the same, and a contribution's title rarely fits a label at all.
  #
  # Read from the record rather than asked of the model, because the row it forgot
  # to describe is the row the citizen cannot tell from the one above it — and a
  # list refuses to be sent at all where two of its rows read alike. Only a fallback:
  # a description the model wrote wins, since it knows what the citizen just asked.
  #
  # The label keeps the action's own words either way. Which record a row points at
  # is worth a second line, not the twenty characters that say what tapping it does.
  def row_description(spec:)
    action, param = parse(spec)

    return phase_row_description(param) if ::Whatsapp::FlowActions.direct_phase?(action)
    return if action != ::Whatsapp::FlowActions::DIRECT_CONTRIBUTION_ACTION

    contribution_row_description(param)
  end

  def phase_row_description(param)
    projekt_phase = ::ProjektPhase.find_by(id: param.to_i)

    return if projekt_phase.blank?

    [::Whatsapp::ProjektLink.title(projekt_phase.projekt), projekt_phase.title]
      .compact_blank
      .join(" · ")
      .presence
  end

  # A contribution's own title, which twenty characters of label cannot hold: the
  # row above says roughly what it is and this line says which one it is. Dated
  # because a citizen's history is where the same title turns up twice — a Beitrag
  # they sent in twice, or two of them named after the same street.
  def contribution_row_description(param)
    contribution = ::Whatsapp::ContributionPill.resolve(param)

    return if contribution.blank?

    [contribution.title, ::Whatsapp::DatePhrase.relative(contribution.created_at)]
      .compact_blank
      .join(" · ")
      .presence
  end

  def phase_projekt_label(param)
    projekt_phase = ::ProjektPhase.find_by(id: param.to_i)

    return if projekt_phase.blank?

    ::Whatsapp::ProjektLink.title(projekt_phase.projekt)
  end

  def proposal_label(param)
    ::Proposal.not_retired.find_by(id: param.to_i)&.title
  end

  # A contribution's own title, which is the fallback rather than the rule here:
  # twenty characters name a projekt but rarely a proposal, so the row the citizen
  # reads carries the title in its description and the model writes something
  # shorter above it. Blank for a contribution that is gone, which drops the row.
  def contribution_label(param)
    ::Whatsapp::ContributionPill.resolve(param)&.title
  end

  # Which way the toggle goes, read off the citizen's own vote at the moment the
  # message is composed rather than carried in the id. The vote is the only thing
  # that can say whether tapping this gives a support or takes one back, and the
  # inbound side reads it again on the tap — so a label built from anything else is
  # a label that can disagree with what happens.
  #
  # Blank for a proposal that is gone, which drops the pill: the same rule every
  # other record-backed label follows.
  def support_toggle_label(param, conversation)
    proposal = ::Proposal.not_retired.find_by(id: param.to_i)

    return if proposal.blank?

    user = conversation.user
    supported = user.present? && proposal.voted_up_by?(user)

    return I18n.t("whatsapp.bot.buttons.support_withdraw") if supported

    I18n.t("whatsapp.bot.buttons.support")
  end

  # Only the options the phase on the table actually offers. This is the check
  # that keeps a category pill from carrying an id belonging to another phase —
  # the tap would be refused by the policy anyway, one message later and with
  # nothing said about why.
  def taxonomy_label(policy, param)
    policy.options.find { |option| option.id.to_s == param.to_s }&.name
  end

  def notification_label(param)
    type = ::Whatsapp::Account::NOTIFICATION_TYPES.find { |known| known.to_s == param.to_s }

    return if type.blank?

    I18n.t("whatsapp.bot.notifications.types.#{type}.short")
  end

  def browse_category_label(param)
    group = ::Whatsapp::CategorizedProjektsQuery.category(key: param)

    return if group.blank?

    I18n.t("custom.projekts.filters.#{param}")
  end

  def parse(spec)
    action, param = spec.to_s.strip.delete_prefix(::Whatsapp::FlowActions::PREFIX)
      .split(::Whatsapp::FlowActions::SEPARATOR, 2)

    return [nil, nil] if action.blank?

    [action.to_sym, param.presence]
  end

  # Nil with a line saying why. Which reason it was decides what to do about it:
  # `unknown_action` is a name that is not one at all and belongs in the tool
  # description, `unlabelled` is a pill the model wrote no words for and whose
  # record could not name it either, `unparseable` an empty or malformed spec, and
  # `unknown_scope` a `show_more` naming a list the bot does not keep.
  def dropped(spec, conversation, reason)
    ::Whatsapp::AiAssistant::DecisionLog.record(
      event: :action_dropped, conversation: conversation, spec: spec, reason: reason
    )

    nil
  end

  # Its own event rather than a line in the reply log. A pill that publishes a
  # draft or posts a comment cannot be undone from the chat, so a mis-offer has
  # to be findable after the fact — and the reply it sat under reads perfectly
  # reasonably either way.
  def record_irreversible_offer(action, conversation)
    return if !IRREVERSIBLE_ACTIONS.include?(action)

    ::Whatsapp::AiAssistant::DecisionLog.record(
      event: :irreversible_offered, conversation: conversation, action: action
    )
  end
end
