module Whatsapp::AssistantActions
  # Which pills the assistant may put under a reply, and nothing about what they
  # are called: the label is the model's sentence, the same way the reply above it
  # is. What stays bounded is the id, because WhatsApp returns the *id* to the
  # webhook and Inbound::TapDispatch is what turns that id into an effect.
  # An id the model invented has nothing behind it — the citizen taps and nothing
  # happens, with no error anywhere — so the set of ids is closed while the words
  # on them are not.
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
  # a pill that publishes or registers support has to be findable afterwards, and
  # "the assistant offered this" is not otherwise distinguishable from "the
  # citizen asked for it".
  IRREVERSIBLE_ACTIONS = %i[draft_publish submit_final support unlink_confirm].freeze

  module_function

  # Every id the assistant may name, for the tool descriptions that list them. The
  # recovery ids belong here too: they are offerable like any other, and without
  # them in the list the model has no way to put a way out beside a question — which
  # is exactly the button a citizen part-way through a submission needs most.
  #
  # The parameterised ones are listed by shape rather than enumerated: the records
  # behind them arrive from whichever tool the model just called, and enumerating a
  # portal's projekts here would be the whole portal in every prompt.
  def offerable_action_names
    (
      (HANDLED_ACTIONS - ::Whatsapp::FlowActions::PARAMETERISED_ACTIONS) +
        ::Whatsapp::Send::RECOVERY_ACTION_IDS.keys
    ).map(&:to_s)
  end

  def parameterised_action_names
    ::Whatsapp::FlowActions::PARAMETERISED_ACTIONS.map(&:to_s)
  end

  # One tappable button from the action id and the label the model wrote, or nil
  # when that is not something it may offer. Nil rather than an exception on
  # purpose: one unusable pill in a set of three should cost that pill, not the
  # reply.
  def button(spec:, label:, conversation:)
    action, param = parse(spec)

    return dropped(spec, conversation, :unparseable) if action.blank?
    return dropped(spec, conversation, :unknown_action) if !::Whatsapp::FlowActions.known?(action)

    title = title_for(action: action, param: param, label: label, conversation: conversation)

    return dropped(spec, conversation, :unlabelled) if title.blank?

    record_irreversible_offer(action, conversation)

    { id: ::Whatsapp::FlowActions.id_for(action: action, param: param), title: title }
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

  # The label read off the thing the pill points at. A projekt that does not
  # exist, a taxonomy option the phase does not offer and a notification type
  # nobody has heard of all come back blank, and a blank pill is not offered —
  # which is the same check that keeps a stale record id from being sent as a
  # button in the first place.
  def record_label(action:, param:, conversation:)
    return if param.blank?

    case action
    when :view_projekt, :participate_projekt then projekt_label(param)
    when :idea_start then phase_projekt_label(param)
    when :support then proposal_label(param)
    when :category
      taxonomy_label(::Whatsapp::DraftTaxonomy.category(conversation.projekt_phase), param)
    when :sentiment
      taxonomy_label(::Whatsapp::DraftTaxonomy.sentiment(conversation.projekt_phase), param)
    when :notify_toggle then notification_label(param)
    when :discover_category then browse_category_label(param)
    end
  end

  def projekt_label(param)
    projekt = ::Projekt.find_by(id: param.to_i)

    return if projekt.blank?

    ::Whatsapp::ProjektLink.title(projekt)
  end

  def phase_projekt_label(param)
    projekt_phase = ::ProjektPhase.find_by(id: param.to_i)

    return if projekt_phase.blank?

    ::Whatsapp::ProjektLink.title(projekt_phase.projekt)
  end

  def proposal_label(param)
    ::Proposal.not_retired.find_by(id: param.to_i)&.title
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
  # record could not name it either, and `unparseable` an empty or malformed spec.
  def dropped(spec, conversation, reason)
    ::Whatsapp::AiAssistant::DecisionLog.record(
      event: :action_dropped, conversation: conversation, spec: spec, reason: reason
    )

    nil
  end

  # Its own event rather than a line in the reply log. A pill that publishes a
  # draft or registers support cannot be undone from the chat, so a mis-offer has
  # to be findable after the fact — and the reply it sat under reads perfectly
  # reasonably either way.
  def record_irreversible_offer(action, conversation)
    return if !IRREVERSIBLE_ACTIONS.include?(action)

    ::Whatsapp::AiAssistant::DecisionLog.record(
      event: :irreversible_offered, conversation: conversation, action: action
    )
  end
end
