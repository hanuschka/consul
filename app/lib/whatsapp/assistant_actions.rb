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

  # A list row is allowed four characters more than a button, and rows are where the
  # longest labels are — a projekt's name, a citizen's own contribution title — so
  # the four are worth threading a length through for. Buttons keep the lower figure
  # rather than both surfaces sharing one: a set of poll options is sent as buttons
  # or as rows depending only on how many there are, so a label written for a row
  # has to survive being put on a button.
  MAX_ROW_TITLE_LENGTH = 24

  # Spent out of the budget rather than added to it — WhatsApp counts it like any
  # other character — which is the whole point: the label gives up a character to
  # say that it gave up the rest.
  TRUNCATION_OMISSION = "…".freeze

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
  # on a public page, a severed account link, and consent to the terms, which is
  # recorded once per number for good.
  IRREVERSIBLE_ACTIONS = %i[
    draft_publish submit_final comment_post unlink_confirm terms_accept
  ].freeze

  # The pills the model may offer but not name. Every other label it offers is a
  # sentence it wrote, checked for length and nothing else, because the dispatcher
  # re-resolves the id on the tap and a poor label costs a badly-worded button.
  #
  # The support toggle is here because the same id the model offers does opposite
  # things: it gives support or takes it back depending on the vote. A label the
  # model wrote can therefore say the precise opposite of what tapping it does, and
  # the citizen has no way to tell. The vote is read when the message is composed
  # and decides both halves of the pill — the direction written into the id
  # (#directed_action) and the fixed words on it — so the model's own words for this
  # one are discarded rather than preferred.
  #
  # The other three are the irreversible pills a citizen still has to be able to
  # recognise: a comment going onto a public page under their name, a contribution
  # going in. That the label has to say so was a sentence in three tool descriptions
  # — the same prompt-level guarantee that let the unlink question promise an erasure
  # it could not deliver — and a "Weiter" on the button that publishes is a citizen
  # who has not been asked. The words are fixed rather than asked for.
  #
  # Not the same thing as a platform-worded pill (#platform_button): there the offer
  # itself is withheld, because what has to be fixed is the sentence above the button
  # and not only the words on it. Here the model still decides when to offer, which is
  # safe because each of these is re-checked on the tap — against the vote, against the
  # digest of what was shown.
  #
  # The rest are the steps a submission passes through again and again — starting
  # one, changing the draft, keeping it as it is, taking or skipping a place,
  # starting over. Worded afresh on every message, one step reached a citizen
  # under six labels in one session, and a button that reads differently each
  # time reads as a different button. Fixed so the same step always reads alike.
  FORCED_LABEL_ACTIONS = %i[
    support_toggle support_register support_withdraw comment_post draft_publish submit_final
    submit_proposal draft_revise submit_anyway location_share location_skip main_menu
  ].freeze

  # The fixed labels that have no record behind them to be read off. `submit_final` is
  # the id `draft_publish` took over and is still accepted as proof of the question
  # having been asked, so it says the same thing rather than something of its own.
  FORCED_LABEL_COPY_KEYS = {
    support_register: "whatsapp.bot.buttons.support",
    support_withdraw: "whatsapp.bot.buttons.support_withdraw",
    comment_post: "whatsapp.bot.buttons.comment_post",
    draft_publish: "whatsapp.bot.buttons.draft_publish",
    submit_final: "whatsapp.bot.buttons.draft_publish",
    submit_proposal: "whatsapp.bot.buttons.submit_proposal",
    draft_revise: "whatsapp.bot.buttons.draft_revise",
    submit_anyway: "whatsapp.bot.buttons.submit_anyway",
    location_share: "whatsapp.bot.buttons.location_share",
    location_skip: "whatsapp.bot.buttons.location_skip",
    main_menu: "whatsapp.bot.buttons.main_menu"
  }.freeze

  # The cancel pill named after what it throws away. "Abbrechen" under a draft
  # was written up as "Entwurf löschen" on one message and "Kommentar abbrechen"
  # on the next; named by the work that is open, it says what tapping it does.
  CANCEL_LABEL_KEYS = {
    draft: "whatsapp.bot.buttons.cancel_draft",
    comment: "whatsapp.bot.buttons.cancel_comment",
    step: "whatsapp.bot.buttons.cancel"
  }.freeze

  # What opens a list, by what its rows are. The model used to word it, and one
  # overview opened under "Projekt wählen" and "Übersicht öffnen" on two
  # consecutive messages.
  LIST_OPENER_KEYS = {
    projekts: "whatsapp.bot.buttons.choose_projekt",
    contributions: "whatsapp.bot.buttons.contribution_choose",
    mixed: "whatsapp.bot.buttons.choose"
  }.freeze

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

  # The offerable ids whose label is fixed, for the tool descriptions that tell
  # the model to leave it empty.
  def fixed_label_action_names
    (
      (FORCED_LABEL_ACTIONS - ::Whatsapp::FlowActions.unofferable) +
        [:idea_start] +
        ::Whatsapp::Send::RECOVERY_ACTION_IDS.keys
    ).map(&:to_s)
  end

  # The one entry point the tools build a model-written pill through. Which of the
  # two namespaces a spec belongs to is not the caller's business, and it stopped
  # being expressible as a fallback the moment a recovery pill could be refused on
  # state: five call sites read a nil from the recovery side as "not a recovery id"
  # and asked the catalog for it, which answered nil again and logged the drop a
  # second time under the wrong reason.
  #
  # `idea_start` on a button says what tapping it does, in the card's words for the
  # phase: offered beside a sentence it is the step, not a choice of projekt.
  def offered_button(spec:, label:, conversation:)
    action, param = parse(spec)

    if ::Whatsapp::Send::RECOVERY_ACTION_IDS.key?(action)
      return recovery_button(spec: spec, conversation: conversation)
    end

    button(
      spec: spec,
      label: button_label(action: action, param: param, label: label, conversation: conversation),
      conversation: conversation
    )
  end

  # The same pill as a list row. A row with `idea_start` is one projekt among
  # several, so it keeps the name it was given: labelled with the step, every
  # row of the list would read the same and WhatsApp refuses the whole list.
  def offered_row(spec:, label:, conversation:)
    action, = parse(spec)

    if ::Whatsapp::Send::RECOVERY_ACTION_IDS.key?(action)
      return recovery_button(spec: spec, conversation: conversation, length: MAX_ROW_TITLE_LENGTH)
    end

    button(spec: spec, label: label, conversation: conversation, length: MAX_ROW_TITLE_LENGTH)
  end

  # The words a button goes out with before any fixed label replaces them: the
  # model's own, except where the step has its card wording.
  def button_label(action:, param:, label:, conversation:)
    return label if action != :idea_start

    phase_action_label(param, conversation).presence || label
  end

  # The opener of a list, read off its rows rather than written by the model.
  def list_opener(row_ids)
    ::Whatsapp.copy(LIST_OPENER_KEYS.fetch(list_kind(row_ids)))
  end

  # Projekts only, contributions only, or anything else, which is an overview.
  def list_kind(row_ids)
    actions = Array(row_ids).map { |row_id| ::Whatsapp::FlowActions.parse(row_id)&.dig(:action) }

    if actions.all? { |action| ::Whatsapp::FlowActions::PROJEKT_CHOICE_ACTIONS.include?(action) }
      :projekts
    elsif actions.all?(::Whatsapp::FlowActions::DIRECT_CONTRIBUTION_ACTION)
      :contributions
    else
      :mixed
    end
  end

  # The pill neither half of which is the model's, for the ids withheld from it
  # entirely (Whatsapp::FlowActions::PLATFORM_WORDED_ACTIONS). #button would refuse
  # these — being unofferable is exactly what they are — so the one thing they still
  # need from here is the irreversible offer being recorded, which is what the tool
  # that acts reads back.
  #
  # The title is composed by the caller rather than looked up here, because it comes
  # out of the same translation batch as the block it is sent with: asking for it
  # again would put a label from one cache state under a sentence from another.
  def platform_button(action:, title:, conversation:)
    return if title.blank?

    record_irreversible_offer(action, conversation)

    { id: ::Whatsapp::FlowActions.id_for(action: action), title: title }
  end

  # The pill a preview tool builds, which is every pill #offered_button builds plus
  # the one that acts on what the preview just showed
  # (Whatsapp::FlowActions::CONFIRMATION_ACTIONS). `confirms` names which of those
  # this preview may carry, so a comment's preview cannot arm publishing a draft and
  # the reverse.
  #
  # The label is the fixed one whatever the model wrote, as it always was for these.
  def confirmation_button(spec:, label:, conversation:, confirms:)
    action, param = parse(spec)

    if !confirmation?(action)
      return offered_button(spec: spec, label: label, conversation: conversation)
    end

    if !confirms.include?(action)
      return dropped(spec, conversation, :confirmation_elsewhere)
    end

    platform_button(
      action: action,
      title: truncated(forced_label(action: action, param: param, conversation: conversation)),
      conversation: conversation
    )
  end

  def confirmation?(action)
    ::Whatsapp::FlowActions.confirmation?(action)
  end

  # Whether the words the model wrote for a pill are the words it ships with. They
  # are not on a forced pill or a confirmation, whose labels are fixed — so a long
  # label written for one of those costs nothing and is not the model's to shorten.
  def written_label?(spec)
    action, = parse(spec)

    !FORCED_LABEL_ACTIONS.include?(action) && !confirmation?(action) &&
      !::Whatsapp::Send::RECOVERY_ACTION_IDS.key?(action)
  end

  # One tappable button from the action id and the label the model wrote, or nil
  # when that is not something it may offer. Nil rather than an exception on
  # purpose: one unusable pill in a set of three should cost that pill, not the
  # reply.
  def button(spec:, label:, conversation:, length: MAX_LABEL_LENGTH)
    action, param = parse(spec)

    return dropped(spec, conversation, :unparseable) if action.blank?
    return dropped(spec, conversation, :unknown_action) if !::Whatsapp::FlowActions.known?(action)

    if confirmation?(action)
      return dropped(spec, conversation, :confirmation_only)
    end

    return dropped(spec, conversation, :unofferable) if ::Whatsapp::FlowActions.unofferable?(action)
    return dropped(spec, conversation, :unknown_scope) if !known_scope?(action, param)
    return dropped(spec, conversation, :nothing_to_tell) if !tells_more?(action, param)

    if !reachable_contribution?(action, param, conversation)
      return dropped(spec, conversation, :unreachable)
    end

    sent_action = directed_action(action, param, conversation)

    return dropped(spec, conversation, :unlabelled) if sent_action.blank?

    title = title_for(
      action: sent_action, param: param, label: label, conversation: conversation, length: length
    )

    return dropped(spec, conversation, :unlabelled) if title.blank?

    record_irreversible_offer(sent_action, conversation)

    { id: ::Whatsapp::FlowActions.id_for(action: sent_action, param: param), title: title }
  end

  # The toggles the model offers, turned into the direction they have at the moment
  # the message is composed. A toggle id read again on the tap does whatever the
  # state says by then — and a citizen who taps "Unterstützen" twice while the reply
  # is still on its way registers the support with the first tap and takes it back
  # with the second. Written into the id, the direction is what the label said, so a
  # repeated tap finds it already done and changes nothing.
  #
  # Nil where there is nothing to offer — a proposal that is gone, or one that can
  # no longer be supported by someone who has not supported it — which drops the
  # pill the same way a blank label did.
  def directed_action(action, param, conversation)
    case action
    when :support_toggle then support_action(param, conversation)
    when :notify_toggle then notification_action(param, conversation)
    else action
    end
  end

  # One of the three parameters checked before the label rather than through it —
  # `view_projekt` and `view_contribution` below are the others, each for a
  # different reason. Most parameterised pills point at a record, and a label the
  # model wrote is accepted without reading that record because the dispatcher
  # resolves it again on the tap. `show_more`'s
  # parameter is a scope name instead: nothing resolves it later, so an invented one
  # is a pill that is tapped and does nothing.
  def known_scope?(action, param)
    return true if action != :show_more

    ::Whatsapp::FlowActions::MORE_SCOPES.include?(param.to_s)
  end

  # The second, and a pill that does read its record before the label: a
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

  # The third, because the tap is not the only thing that reads the record: a
  # row the model labelled itself takes its second line from the contribution's
  # own title. One this citizen may not open — someone else's draft, a proposal
  # still awaiting moderation — is dropped here, the same as one that is gone,
  # rather than offered and then answered with nothing on the tap.
  def reachable_contribution?(action, param, conversation)
    return true if action != ::Whatsapp::FlowActions::DIRECT_CONTRIBUTION_ACTION

    contribution_for(param, conversation).present?
  end

  # The records one message's pills point at, read at once. A list of ten
  # contributions asked the same record three times a row — whether it may be
  # opened, what it is called, what goes under it — and every support pill asked
  # whether its proposal may still be supported: a query each, thirty for one list.
  # Inside the block they are answered from one query per kind.
  #
  # Scoped to the one message being built rather than to the turn: a draft
  # published earlier in the same turn becomes openable, and a cache held that long
  # would go on answering that it is not.
  def with_records_preloaded(specs, conversation:)
    previous = ::Current.whatsapp_pill_records
    ::Current.whatsapp_pill_records = preloaded_records(specs, conversation)

    yield
  ensure
    ::Current.whatsapp_pill_records = previous
  end

  PillRecords = Struct.new(:contributions, :supportable, keyword_init: true)

  def preloaded_records(specs, conversation)
    parsed = Array(specs).map { |spec| parse(spec) }

    contribution_params = parsed.filter_map do |action, param|
      param if action == ::Whatsapp::FlowActions::DIRECT_CONTRIBUTION_ACTION
    end

    proposal_ids = parsed.filter_map do |action, param|
      param.to_i if action == :support_toggle && param.present?
    end

    PillRecords.new(
      contributions: ::Whatsapp::ContributionPill.resolve_all(
        contribution_params, user: conversation.user
      ),
      supportable: supportable_by_id(proposal_ids)
    )
  end

  def supportable_by_id(proposal_ids)
    return {} if proposal_ids.empty?

    actionable =
      ::Whatsapp::ReachableContributionsQuery
        .actionable_proposals
        .where(id: proposal_ids)
        .pluck(:id)
        .to_set

    proposal_ids.index_with { |id| actionable.include?(id) }
  end

  # Read from the message's preload where one is running and holds the pill, and
  # asked on its own otherwise — the card and the notification follow-ups build
  # their pills one at a time.
  def contribution_for(param, conversation)
    preloaded = ::Current.whatsapp_pill_records&.contributions

    return preloaded[param.to_s] if preloaded&.key?(param.to_s)

    ::Whatsapp::ContributionPill.resolve(param, user: conversation.user)
  end

  # The recovery pills whose offer depends on the state rather than on the id being
  # known, each beside the question that decides it. Three of the four: `help` is the
  # one way out that is always true, which is why it is what a dead end falls back to.
  #
  # They share a shape. Each promises to act on something the conversation may not
  # have, and each degrades quietly rather than loudly when it does not: cancelling
  # with nothing written drops the phase exactly as starting over does, so the reply
  # carries two ways out of a message that needs one — and the worse of the two, since
  # it answers with a closing line where the other shows what is open. Trying again
  # with no failed turn stored reaches the tap handler, which declines it and lets it
  # fall through as a bare note about a button press. Opening the login link again
  # with none outstanding has no handler at all and is answered by improvisation.
  #
  # In every case the citizen taps a button that says it will do something and is
  # answered by the assistant guessing. Once the state is there the pill means what it
  # says, and all three belong under the message.
  STATEFUL_RECOVERY_ACTIONS = {
    cancel: ->(conversation) { conversation.unsaved_work? },
    retry: ->(conversation) { conversation.replayable_turn? },
    link_retry: ->(conversation) { conversation.awaiting_link? }
  }.freeze

  # A recovery pill keeps its own id namespace — the inbound side reads those
  # before the catalog's, and that ordering is what lets a "cancel" beside two
  # ordinary pills be understood without anything else knowing about it.
  #
  # Dropped rather than relabelled when the state does not support it, and dropped
  # here rather than trusted to the prompt: the vocabulary the model reads is built
  # once per process, so the conversation is the only place the rule can actually be
  # enforced. The slot it frees is not backfilled: nothing is appended to a recovery
  # line any more except the way back, and that one is added on the way out.
  #
  # Labelled from the copy like the recovery lines' own pills, so a way out reads
  # the same whether the model offered it or a fixed line did.
  def recovery_button(spec:, conversation:, length: MAX_LABEL_LENGTH)
    action, = parse(spec)
    recovery_id = ::Whatsapp::Send::RECOVERY_ACTION_IDS[action]

    return if recovery_id.blank?

    if !offerable_recovery?(action, conversation)
      return dropped(spec, conversation, :recovery_unavailable)
    end

    title = truncated(recovery_label(action, conversation), length: length)

    return if title.blank?

    { id: recovery_id, title: title }
  end

  # The one place a recovery pill's words come from, for the model's pills and
  # for Whatsapp::Send's fixed lines alike.
  def recovery_label(action, conversation)
    if action == :cancel
      return ::Whatsapp.copy(CANCEL_LABEL_KEYS.fetch(cancelled_work(conversation)))
    end

    ::Whatsapp.copy("whatsapp.bot.buttons.#{action}")
  end

  # Which of the three things a cancel tap throws away, the draft first as the
  # larger loss.
  def cancelled_work(conversation)
    if conversation.unsaved_submission?
      :draft
    elsif conversation.pending_comment.present?
      :comment
    else
      :step
    end
  end

  # Asked of the conversation as it stands when the message is built, which is when
  # the pill is sent: a draft that appears later in the same turn belongs to the
  # message after this one.
  def offerable_recovery?(action, conversation)
    available = STATEFUL_RECOVERY_ACTIONS[action]

    return true if available.blank?

    available.call(conversation)
  end

  # The same question asked ahead of the reply rather than of one pill in it, for the
  # prompt line that keeps the refusal rare. Enforcement does not depend on it — the
  # gate above runs whatever the model was told — so this is allowed to be advice.
  def unavailable_recovery_actions(conversation)
    STATEFUL_RECOVERY_ACTIONS
      .reject { |_, available| available.call(conversation) }
      .keys
      .map(&:to_s)
  end

  # The model's own words, shortened to what the surface holds. WhatsApp's own
  # truncation is mid-word and silent, so a label that is one character too long
  # arrives as a fragment; cutting it here is what puts a mark on the cut.
  #
  # Falls back to the record's own name for a parameterised pill the model left
  # unlabelled — a projekt's title as the portal writes it is better than a
  # paraphrase, and it is also what proves the record exists.
  def title_for(action:, param:, label:, conversation:, length: MAX_LABEL_LENGTH)
    if FORCED_LABEL_ACTIONS.include?(action)
      return truncated(
        forced_label(action: action, param: param, conversation: conversation), length: length
      )
    end

    written = truncated(label, length: length)

    return written if written.present?
    return if !::Whatsapp::FlowActions.parameterised?(action)

    truncated(
      record_label(action: action, param: param, conversation: conversation), length: length
    )
  end

  # Cut where the budget runs out and marked with an ellipsis, rather than at the
  # last word boundary before it. A boundary cut with nothing to show for itself is
  # how "Kommentar veröffentlichen" reached a citizen as "Kommentar" — not a
  # shortened label but a different, shorter one, under a message asking them to tap
  # it. The boundary was never a rule either: a German compound holds no space to
  # fall back to, so "Benachrichtigungseinstellungen" was hard-cut mid-word anyway
  # and only labels that happened to have an early space were treated differently.
  #
  # The length is asked for by a caller that has already spent some of the budget on
  # something of its own — a poll option's number, which its own line in the message
  # text carries too, so the wording is what gives way rather than the number that
  # pairs the two — or by one whose surface is allowed more of it than a button is.
  def truncated(label, length: MAX_LABEL_LENGTH)
    text = label.to_s.squish

    return if text.blank?

    shortened = text.truncate(length, omission: TRUNCATION_OMISSION)

    record_truncation(text, length) if shortened != text

    shortened
  end

  # Whether the words fit whole, asked without producing the cut: a probe that went
  # through #truncated would count a truncation that never ships against the rate
  # below.
  def fits?(text, length)
    text.to_s.squish.length <= length
  end

  # What the citizen will actually read on the pills, for the tool to hand back to
  # the model — but only where the model wrote words of its own and they did not
  # survive. The sentence above the buttons is composed before the buttons exist, so
  # a model that is not told goes on to ask the citizen to tap wording no button
  # carries: one message contradicting itself on a single screen.
  #
  # A pill the model left unlabelled on purpose is not one of these. The tool
  # descriptions ask for exactly that wherever a record names itself better than a
  # paraphrase would, so reporting those would put a note on most turns — and a note
  # that arrives every turn is one that stops being read, which is the whole reason
  # this is silent whenever every written label survived.
  #
  # Worded for either cause: a label cut to fit, or one replaced by the fixed words
  # its step always carries (FORCED_LABEL_ACTIONS). Both leave the model's sentence
  # naming words no button shows.
  def wording_note(offers)
    changed = offers.filter_map do |written, title|
      words = written.to_s.squish

      next if words.blank? || title.blank? || words == title

      "\"#{title}\""
    end

    return if changed.empty?

    "#{changed.size == 1 ? "One button does" : "Some buttons do"} not carry the words you " \
      "wrote — the citizen reads #{changed.join(", ")}. Say it that way if you refer to " \
      "#{changed.size == 1 ? "it" : "them"} again."
  end

  # The label of a translated fixed line, as it will actually arrive. Preferring the
  # translation, but not at the price of arriving shortened where the copy behind it
  # would have fitted whole.
  #
  # The question used to be *where* the cut fell, and a cut that landed on a word
  # boundary was kept — which is precisely how a first word shipped as though it were
  # the label. Now that every cut says so, the only question left is whether one
  # happened at all: a label in the portal's own language that fits beats one in the
  # citizen's that has been shortened, which is the same trade BotCopyService already
  # makes whenever a translation cannot be had at all. German and Turkish compounds
  # are what make it come up — past twenty characters they have no shorter form.
  #
  # Blank is answered by the written copy rather than by nil: BotCopyService cannot
  # hand back a blank line — a mismatched count falls the whole message back to the
  # copy as written — but a blank title is the one value WhatsApp refuses the message
  # over, so this never returns one while the copy behind it has words.
  def fitting_label(translated:, original:, length: MAX_LABEL_LENGTH)
    text = translated.to_s.squish
    written = original.to_s.squish

    return truncated(written, length: length) if text.blank?
    return text if fits?(text, length)

    if fits?(written, length)
      record_discarded_translation(text, written)

      return written
    end

    truncated(text, length: length)
  end

  # The words of a pill the model may offer but not name, in whichever of the two
  # shapes it has: a fixed line of copy, or a label read off the record the pill
  # points at. The copy shape is checked first because the parameterless ones have no
  # record at all — #record_label's own first guard would answer nil for them, and a
  # blank title is the one value WhatsApp refuses the whole message over.
  def forced_label(action:, param:, conversation:)
    key = FORCED_LABEL_COPY_KEYS[action]

    return ::Whatsapp.copy(key) if key.present?

    record_label(action: action, param: param, conversation: conversation)
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
    when :view_contribution then contribution_label(param, conversation)
    when :idea_start then phase_projekt_label(param)
    when :phase_open then phase_action_label(param, conversation)
    when :phase_contributions then ::Whatsapp.copy("whatsapp.bot.buttons.phase_contributions")
    when :support then proposal_label(param)
    when :category
      taxonomy_label(::Whatsapp::DraftTaxonomy.category(conversation.projekt_phase), param)
    when :sentiment
      taxonomy_label(::Whatsapp::DraftTaxonomy.sentiment(conversation.projekt_phase), param)
    when :notify_enable, :notify_disable then notification_label(param)
    when :discover_category then browse_category_label(param)
    when :show_more then ::Whatsapp.copy("whatsapp.bot.buttons.show_more")
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
  #
  # The citizen travels with it for the same reason the wording does. A vote they have
  # already taken part in is labelled as such on the card, and a pill beside a reply
  # still reading "Jetzt abstimmen" would be the card's own mark contradicted by the
  # message under it.
  def phase_action_label(param, conversation)
    projekt_phase = ::ProjektPhase.find_by(id: param.to_i)

    return if projekt_phase.blank?

    ::Whatsapp::ProjektCardActions.label_for(projekt_phase, user: conversation.user)
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
  def row_description(spec:, conversation:)
    action, param = parse(spec)

    return phase_row_description(param) if phase_row?(action)
    return if action != ::Whatsapp::FlowActions::DIRECT_CONTRIBUTION_ACTION

    contribution_row_description(param, conversation)
  end

  # `idea_start` carries a phase id like the direct phase pills, but its row is a
  # projekt choice and shows the name alone — until two of them share that name,
  # which is one projekt offered once per phase (SendList#dated_where_alike).
  def phase_row?(action)
    ::Whatsapp::FlowActions.direct_phase?(action) || action == :idea_start
  end

  # The phase's name, its dates and its projekt, in that order. Dated because a
  # projekt may run three phases all called "Vorschläge", and the dates are then the
  # only thing that differs; ahead of the projekt's name because the description is
  # cut at its end, and the name is what the row above usually says already.
  def phase_row_description(param)
    projekt_phase = ::ProjektPhase.find_by(id: param.to_i)

    return if projekt_phase.blank?

    [
      projekt_phase.title,
      ::Whatsapp::DatePhrase.range(projekt_phase.start_date, projekt_phase.end_date),
      ::Whatsapp::ProjektLink.title(projekt_phase.projekt)
    ]
      .compact_blank
      .join(" · ")
      .presence
  end

  # A contribution's own title, which twenty characters of label cannot hold: the
  # row above says roughly what it is and this line says which one it is. Dated
  # because a citizen's history is where the same title turns up twice — a Beitrag
  # they sent in twice, or two of them named after the same street.
  def contribution_row_description(param, conversation)
    contribution = contribution_for(param, conversation)

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
  def contribution_label(param, conversation)
    contribution_for(param, conversation)&.title
  end

  # Which way the toggle goes, read off the citizen's own vote at the moment the
  # message is composed and carried in the id. The vote is the only thing that can
  # say whether tapping this gives a support or takes one back, and the label is
  # the fixed copy of the direction chosen here — so the words on the pill and what
  # the tap does come from the one reading.
  #
  # Nil for a proposal that is gone, which drops the pill: the same rule every
  # other record-backed label follows.
  def support_action(param, conversation)
    proposal = ::Proposal.not_retired.find_by(id: param.to_i)

    return if proposal.blank?

    user = conversation.user

    return :support_withdraw if user.present? && proposal.voted_up_by?(user)
    return if !supportable?(proposal)

    :support_register
  end

  # The same for a notification switch: a type that is on is offered as the switch
  # that turns it off. Nil for a type nobody has heard of, which drops the pill.
  def notification_action(param, conversation)
    type = notification_type(param)

    return if type.blank?
    return :notify_disable if conversation.whatsapp_account.notifies?(type)

    :notify_enable
  end

  # Asked only on the way to "Unterstützen": a support already given is theirs to
  # take back whatever has become of the proposal since, and the withdraw pill
  # above stays offered for it.
  def supportable?(proposal)
    preloaded = ::Current.whatsapp_pill_records&.supportable

    return preloaded[proposal.id] if preloaded&.key?(proposal.id)

    ::Whatsapp::ReachableContributionsQuery.actionable_proposals.exists?(id: proposal.id)
  end

  # Only the options the phase on the table actually offers. This is the check
  # that keeps a category pill from carrying an id belonging to another phase —
  # the tap would be refused by the policy anyway, one message later and with
  # nothing said about why.
  def taxonomy_label(policy, param)
    policy.options.find { |option| option.id.to_s == param.to_s }&.name
  end

  def notification_label(param)
    type = notification_type(param)

    return if type.blank?

    ::Whatsapp.copy("whatsapp.bot.notifications.types.#{type}.short")
  end

  def notification_type(param)
    ::Whatsapp::Account::NOTIFICATION_TYPES.find { |known| known.to_s == param.to_s }
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
  # record could not name it either, `unparseable` an empty or malformed spec,
  # `unknown_scope` a `show_more` naming a list the bot does not keep,
  # `confirmation_only` a publishing pill offered away from its preview, and
  # `confirmation_elsewhere` one offered under the other preview.
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

  # Counted rather than prevented, because what overruns is a sentence the model
  # wrote and the same pill fits one turn and not the next — so "how often" has no
  # answer a single line could give. The rate is what says whether the budget the
  # prompt states is one the model can write to or one it is quietly missing, and
  # the label is kept with it because a budget missed by two characters and one
  # missed by twenty are different problems with different fixes.
  #
  # Without a conversation: #truncated is reached from the card and the poll as well
  # as from a turn, and a count that only held the ones that had a conversation to
  # hand would be read as the whole.
  def record_truncation(text, length)
    ::Whatsapp::AiAssistant::DecisionLog.record(
      event: :label_truncated, label: text, over_by: text.length - length
    )
  end

  # A citizen answered in the portal's language on one button because theirs did not
  # fit. BotCopyService is told the budget, so this rising says the instruction is
  # not one the language can be held to rather than one the model ignored — and the
  # fix for that is a shorter German source line, not a firmer prompt.
  #
  # Both sides are kept because both are needed to act: the translation names the
  # language it is in far better than a code would, and the line it was written from
  # is what would have to be shortened. No locale is asked for — the only place the
  # turn's language is held is a cache key built from a database read, which is a
  # query per discarded button to learn what the text already says.
  def record_discarded_translation(text, written)
    ::Whatsapp::AiAssistant::DecisionLog.record(
      event: :translation_discarded, translated: text, written: written
    )
  end
end
