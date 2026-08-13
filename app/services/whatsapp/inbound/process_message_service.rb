class Whatsapp::Inbound::ProcessMessageService < ApplicationService
  # The one keyword list left. Every other typed message is read by a model,
  # but a typed opt-out word must end messages whether or not a provider is
  # reachable — an outage that keeps broadcasting to a number that asked us to
  # stop is the failure nothing may allow.
  OPT_OUT_KEYWORDS = ["stop", "stopp", "abmelden", "unsubscribe"].freeze

  def initialize(whatsapp_message:, raw_message: {})
    @whatsapp_message = whatsapp_message
    @raw_message = raw_message || {}
  end

  def call
    return if !::Whatsapp.enabled?

    conversation.update!(last_inbound_at: latest_inbound_at)

    consume_pending_question

    return if handle_stop_keywords
    return if handle_message_intent
    return if account.opt_out_at.present?
    return Whatsapp::Flows::FirstContactService.call(conversation:) if first_contact?

    # The disclosure heads the citizen's first message, so it is sent before
    # anything below can reply. Once per number rather than once per 24-hour
    # window: a regular who reads it every day stops reading it at all. A first
    # contact is the exception, its own opening message already carries it.
    Whatsapp::Flows::AiDisclosureService.call(conversation:) if !account.ai_disclosed?

    return if handle_recovery_action
    return if handle_flow_action
    return if @whatsapp_message.audio? && inbound_text.blank?

    entry = capture_entry_token

    return handle_unlinked(entry) if account.user.blank? && !guest_participation?
    return handle_entry(entry) if entry.present?
    return if handle_stale_flow
    return if routed_by_assistant?

    dispatch_step
  end

  private

    # A phase that takes guest submissions on the web takes them here too, so an
    # unlinked number is not stopped at the door. It is still stopped later, by
    # the restrictions the phase carries — see ResourceCreationValidationService.
    def guest_participation?
      conversation.projekt_phase&.guest_participation?
    end

    def submission_author
      @submission_author ||= Whatsapp::Drafting::SubmissionAuthorService.call(conversation:)
    end

    # Everything above the assistant is protocol rather than dialogue — the
    # typed STOP word, the channel-intent reading, a tapped pill, a scanned QR
    # code. The assistant sees only what is left, and hands back anything the
    # flow owns.
    #
    # An unlinked guest submitter skips it: half its tools act on a Consul
    # account, and a guest reaching them would only produce errors it cannot
    # explain. Their whole path is the deterministic drafting flow.
    def routed_by_assistant?
      return false if !::Ai::Settings.ai_available?
      return false if account.user.blank?
      return false if tapped_reply_id.present?

      # A shared location is an answer to the step that asked for it, and it
      # carries no text at all — routing it would pay for a completion on an
      # empty message and could answer a pin with conversation.
      return false if inbound_location.present?

      result = Whatsapp::AiAssistant::RouterService.call(
        conversation: conversation,
        inbound_text: inbound_text,
        inbound_message_id: inbound_message_id
      )

      return false if !result.success?

      result.outcome != :flow
    end

    # A tapped row or button already says exactly what it means, and the text
    # WhatsApp sends alongside it is only that row's own label. The steps below
    # read the id; sending the label to the assistant instead would pay for a
    # completion to re-derive it, and risk a tapped "Yes, submit it" being
    # answered as conversation rather than publishing the draft.
    def tapped_reply_id
      list_reply_id.presence || button_reply_id.presence
    end

    def first_contact?
      return true if @whatsapp_message.welcome? && !account.greeted?

      account.user_id.blank? && !account.greeted?
    end

    # Only ever forwards: a retried or out-of-order delivery must not rewind the
    # conversation's clock.
    def latest_inbound_at
      [@whatsapp_message.sent_at || Time.current, conversation.last_inbound_at].compact.max
    end

    def account
      @account ||= @whatsapp_message.whatsapp_account
    end

    def conversation
      @conversation ||= account.conversation
    end

    # The catalog uses one word for two things: "Stop" abandons what is in
    # progress (C21), and "STOP" ends all messages for good (E34). Decided here
    # rather than inside either service — getting it wrong means a citizen who
    # wanted to cancel is silently unsubscribed instead.
    def handle_stop_keywords
      return false if !OPT_OUT_KEYWORDS.include?(normalized_text)

      if conversation.drafting?
        Whatsapp::Flows::CancelService.call(conversation:)
      else
        Whatsapp::Flows::MessageDeliveryService.disable(conversation:)
      end

      true
    end

    # Everything the keyword above does not decide is decided by one model
    # reading: leaving the channel, coming back to it, or abandoning what is in
    # progress, in whatever words the citizen chose. One call rather than one
    # per question — the checks it replaced each paid their own completion on
    # the same message.
    #
    # Never for a tapped pill, whose label the citizen did not write: those are
    # routed by their ids two gates below. A verdict the conversation's state
    # rules out is dropped rather than acted on — the model is told the state,
    # but what it answers is still only a reading.
    def handle_message_intent
      return false if tapped_reply_id.present?

      case message_intent
      when :opt_out
        return false if account.opt_out_at.present?

        Whatsapp::Flows::MessageDeliveryService.disable(conversation:)
      when :opt_in
        return false if account.opt_out_at.blank?

        Whatsapp::Flows::MessageDeliveryService.enable(conversation:)
      when :abort
        return false if !interaction_open?

        Whatsapp::Flows::CancelService.call(conversation:)
      else
        return false
      end

      true
    end

    # Asked once per message; every branch of handle_message_intent consults
    # the same verdict.
    def message_intent
      @message_intent ||= Whatsapp::AiAssistant::MessageIntentService.call(
        inbound_text: inbound_text,
        interaction_open: interaction_open?,
        opted_out: account.opt_out_at.present?
      )
    end

    # A word that cannot mean "leave the channel" dismisses whatever the bot last
    # asked. Any step other than idle is that, and so is an idle conversation
    # holding a question: the assistant's own button replies leave the step at
    # idle, so the step alone cannot tell the two apart.
    def interaction_open?
      return true if !conversation.idle?

      pending_question?
    end

    def pending_question?
      @pending_question
    end

    # Read and cleared in the same breath. The flag answers "was the bot's last
    # message a question", which is true only for the message that follows it —
    # consumed before any gate below can return early, so no branch can leave it
    # set and turn an "abbrechen" days later into a cancellation.
    def consume_pending_question
      @pending_question = conversation.context["pending_question"].present?

      return if !@pending_question

      conversation.merge_context!(pending_question: nil)
    end

    # Handled ahead of the step dispatcher: a tapped recovery button must not be
    # read as idea text by whichever step happens to be active.
    #
    # Read off either shape of tap. A list carries no buttons beside it, so a
    # message offering rows has to put its way out among them, and a recovery id
    # cannot collide with a flow one: the two are built by different modules from
    # different prefixes.
    def handle_recovery_action
      action = Whatsapp::Outbound.recovery_action_from(tapped_reply_id)

      return false if action.blank?

      case action
      when :help then Whatsapp::Flows::HelpService.call(conversation:)
      when :cancel then Whatsapp::Flows::CancelService.call(conversation:)
      when :retry then retry_last_action
      end

      true
    end

    def handle_flow_action
      return false if flow_action.blank?

      dispatch_flow_action(flow_action[:action], flow_action[:param])

      true
    end

    def flow_action
      return @flow_action if defined?(@flow_action)

      @flow_action = Whatsapp::FlowActions.parse(tapped_reply_id)
    end

    # One place every pill in the catalog lands. Actions that need an account
    # are refused here rather than in each service, so reading the portal never
    # dead-ends into "connect an account" and participating never silently
    # skips the check.
    # Making a submission, which a guest phase does allow: these need an
    # account only when the phase they point at does.
    SUBMISSION_ACTIONS = %i[
      idea_start category sentiment draft_publish draft_revise resume restart
      image_upload image_generate image_skip location_share location_skip
      submit_final submit_anyway
    ].freeze

    # Supporting a proposal, reading your own submissions, changing
    # notification settings and unlinking all act on a Consul account, and a
    # guest has nothing to stand in for it with.
    #
    # my_contributions is here because the help list offers it to unlinked
    # numbers too: without the check it answers "you have not submitted
    # anything yet" to someone whose account is full of submissions, and never
    # mentions that linking is the missing part.
    ACCOUNT_ONLY_ACTIONS = %i[
      support support_instead support_prompt comment_prompt my_contributions
      notify_toggle notifications_done notifications_open
      unlink_confirm unlink_cancel unlink_start
    ].freeze

    # Derived from the two groups rather than listed a third time. The union is
    # what account_required? gates on, so an action named in only one of the
    # source lists is still gated; written out by hand, an account-only pill
    # left out of the union would skip the check entirely and reach the flow
    # with no user behind it.
    ACCOUNT_ACTIONS = (SUBMISSION_ACTIONS + ACCOUNT_ONLY_ACTIONS).freeze

    GUEST_ELIGIBLE_ACTIONS = SUBMISSION_ACTIONS

    def dispatch_flow_action(action, param)
      return Whatsapp::Flows::SendLoginLinkService.call(conversation:) if
        account_required?(action, param)

      case action
      when :link_yes, :link_retry
        Whatsapp::Flows::SendLoginLinkService.call(conversation:)
      when :link_switch
        Whatsapp::Flows::SendLoginLinkService.after_switch(conversation:)
      when :link_later
        Whatsapp::Flows::LinkDeclinedService.call(conversation:)
      when :discover
        dispatch_discovery
      when :discover_public
        Whatsapp::Flows::PublicDiscoveryService.call(conversation:)
      when :submit_proposal
        Whatsapp::Flows::SubmitProposalService.call(conversation:)
      when :view_projekt
        send_projekt_card(param)
      when :my_contributions
        Whatsapp::Flows::ContributionsService.call(conversation:)
      when :main_menu
        Whatsapp::Flows::MainMenuService.greeting(conversation:)
      when :support_prompt
        send_menu_prompt("whatsapp.bot.help_menu.prompts.support")
      when :comment_prompt
        send_menu_prompt("whatsapp.bot.help_menu.prompts.comment")
      when :notifications_open
        Whatsapp::Flows::NotificationSettingsService.call(conversation:)
      when :unlink_start
        Whatsapp::Flows::UnlinkService.ask(conversation:)
      when :dismiss, :unlink_cancel
        conversation.reset_flow!
      when :unlink_confirm
        Whatsapp::Flows::UnlinkService.confirm(conversation:)
      when :notify_toggle
        Whatsapp::Flows::ToggleNotificationService.call(conversation:, type: param)
      when :notifications_done
        finish_notification_settings
      when :idea_start
        start_phase_flow(param)
      when :category
        assign_category(param)
      when :sentiment
        assign_sentiment(param)
      when :draft_publish
        ask_image
      when :image_upload
        ask_image_upload
      when :image_generate
        generate_image_then_confirm
      when :image_skip, :submit_final
        ask_location
      when :location_share
        share_location
      when :location_skip
        publish
      when :draft_revise
        ask_revision
      when :submit_anyway
        draft_despite_duplicates
      when :resume
        resume_flow
      when :restart
        restart_flow
      when :support
        Whatsapp::Flows::RegisterSupportService.call(conversation:, proposal_id: param)
      when :support_instead
        support_instead_of_drafting(param)
      end
    end

    # The duplicate offer's own support pill: the citizen chose an existing
    # proposal over writing their own, so the submission it interrupted is over
    # and the menu is what follows publishing too.
    def support_instead_of_drafting(proposal_id)
      registered = Whatsapp::Flows::RegisterSupportService.call(
        conversation:, proposal_id: proposal_id
      )

      # Only once the support actually landed. A proposal retired between the
      # offer and the tap answers "that one is gone" — ending the flow there
      # would throw away the idea they were part-way through submitting, and
      # they would have to type the whole thing again.
      return if !registered

      Whatsapp::Flows::MainMenuService.greeting(conversation:)
    end

    # A stale step with nothing left to offer — every proposal retired, the
    # context purged — asks for the idea again rather than leaving the citizen
    # on a question that can no longer be put.
    def reask_duplicate_choice
      asked = Whatsapp::Flows::AskDuplicateChoiceService.reask(conversation:)

      return if asked

      Whatsapp::Flows::AskIdeaService.call(conversation:)
    end

    # The idea was screened on the way in, so it goes straight to generation.
    # Nothing to draft from means the context was purged between the offer and
    # the tap; asking again is the only way forward.
    def draft_despite_duplicates
      if conversation.context["last_idea_text"].blank?
        return Whatsapp::Flows::AskIdeaService.call(conversation:)
      end

      return if refuse_if_not_permitted

      Whatsapp::Flows::BuildDraftService.from_accepted_idea(
        conversation:, inbound_message_id:
      )
    end

    def account_required?(action, param)
      return false if !ACCOUNT_ACTIONS.include?(action)
      return false if account.user.present?

      !guest_action?(action, param)
    end

    # Read from the phase the action points at rather than the conversation's:
    # idea_start carries its own phase id, and it is the tap that opens the flow
    # in the first place.
    def guest_action?(action, param)
      return false if !GUEST_ELIGIBLE_ACTIONS.include?(action)

      target_phase_for(action, param)&.guest_participation?
    end

    def target_phase_for(action, param)
      return conversation.projekt_phase if action != :idea_start

      ::ProjektPhase.find_by(id: param)
    end

    # A help row that names something the assistant resolves rather than a flow
    # the bot owns. It asks the question and stops: the citizen's next message
    # is free text, and the assistant's own tools find the proposal in it.
    def send_menu_prompt(body_key)
      conversation.reset_flow!

      Whatsapp::Outbound.text(
        account:,
        body: Whatsapp.phrase(body_key)
      )
    end

    # The same branch whether the assistant called show_projekts or the citizen
    # tapped a pill that offers it. The pill is on the help list, which is what
    # an unlinked number is answered with, so the two cannot differ: the account
    # listing dead-ends for a guest and the public one does not.
    def dispatch_discovery
      return Whatsapp::Flows::PublicDiscoveryService.call(conversation:) if account.user.blank?

      Whatsapp::Flows::DiscoveryService.call(conversation:)
    end

    def finish_notification_settings
      conversation.reset_flow!

      Whatsapp::Outbound.text(
        account:,
        body: Whatsapp.phrase("whatsapp.bot.notifications.saved")
      )
    end

    # Someone who scanned a QR code has just said what they want, and someone
    # mid-login is waiting on the link itself: both get it. A number that wrote
    # in with neither has not asked for a link — it declined one earlier, or its
    # link went cold — so the question is put again instead.
    def handle_unlinked(entry)
      return Whatsapp::Flows::WelcomeBackService.call(conversation:) if
        entry.blank? && !account.awaiting_link?

      Whatsapp::Flows::SendLoginLinkService.call(conversation:)
    end

    # A phase QR code names the phase, so the citizen has already chosen and is
    # asked for their idea. A projekt QR code with one open phase has chosen only
    # the projekt: they get its card first, because the phase is this bot's
    # inference and not their decision.
    def handle_entry(entry)
      return Whatsapp::Flows::RefuseParticipationService.call(conversation:, reason: :no_open_phase) if
        entry == :projekt_without_phase
      return Whatsapp::Flows::DiscoveryService.call(conversation:, projekt: entry_projekt) if
        entry == :projekt_choice

      return Whatsapp::Flows::ProposalPromptService.call(
        conversation:, projekt_phase: conversation.projekt_phase
      ) if entry == :projekt

      Whatsapp::Flows::AskIdeaService.call(conversation:)
    end

    # A draft older than the catalog's 3600 minutes is not resumed silently.
    # Only asked once — the question itself moves the step, so the next message
    # is an answer to it rather than a second asking.
    def handle_stale_flow
      return false if !conversation.drafting?
      return false if conversation.step == "awaiting_resume_decision"
      return false if !conversation.stale_flow?

      Whatsapp::Flows::ResumeOrRestartService.call(conversation:)

      true
    end

    # The recap goes first either way: hours or days passed since the draft was
    # started, and the step being resumed says nothing about which projekt it
    # belongs to. The draft can also be gone by then — retention purges, an admin
    # deleting the phase — in which case the idea is asked for again inside the
    # same phase rather than sending the citizen back to the entry question.
    #
    # A phase deleted outright leaves nothing to resume into and nothing for
    # AskIdeaService to move the step with, so it restarts instead — otherwise
    # every later message would re-ask the resume question it cannot answer.
    def resume_flow
      return restart_flow if conversation.projekt_phase.blank?

      # The clock the staleness question is asked off is only stamped by
      # start_flow!, and resuming moves the step without going through it. Left
      # alone, the resumed step would be found stale again by the citizen's very
      # next message and the same question asked forever.
      conversation.merge_context!(flow_started_at: Time.current.iso8601)

      Whatsapp::Flows::ResumeRecapService.call(conversation:)

      return Whatsapp::Flows::PresentDraftService.first_draft(conversation:) if
        conversation.draft_resource.present?

      Whatsapp::Flows::AskIdeaService.call(conversation:)
    end

    # Starting over drops the draft and asks the entry question again rather than
    # the idea question: by the time the resume prompt is answered the citizen may
    # not remember which projekt the conversation was in, and "tell me your idea"
    # names none. SubmitProposalService re-derives what is open, so a phase that
    # closed in the meantime cannot be restarted into.
    def restart_flow
      conversation.reset_flow!

      Whatsapp::Flows::SubmitProposalService.call(conversation:)
    end

    # The card on its own, for a citizen who wanted to look before deciding. No
    # flow is started and nothing is remembered: the submission button on the
    # card they were just sent is still there to come back to.
    def send_projekt_card(projekt_id)
      projekt = ::Projekt.find_by(id: projekt_id)

      return Whatsapp::Flows::HelpService.call(conversation:) if projekt.blank?

      Whatsapp::Flows::SendProjektCardService.call(conversation:, projekt: projekt)
    end

    def start_phase_flow(projekt_phase_id)
      projekt_phase = ::ProjektPhase.find_by(id: projekt_phase_id.to_i)

      return Whatsapp::Flows::RefuseParticipationService.call(conversation:, reason: :phase_missing) if
        !Whatsapp::EligiblePhasesQuery.eligible?(projekt_phase)

      Whatsapp::Flows::StartPhaseFlowService.call(conversation:, projekt_phase:)
    end

    # Before the record exists the answer goes into the stashed draft data,
    # because the validation it satisfies runs at creation and the record cannot
    # be written until it is satisfied. Afterwards it goes onto the record,
    # where the citizen is correcting a choice rather than supplying a missing
    # one. Either way CompleteDraftService decides what is still outstanding.
    def assign_category(label_id)
      return stash_draft_choice(:projekt_label_ids, [label_id.to_i]) if pre_creation_draft?

      assigned = Whatsapp::DraftCategory.assign(
        conversation.draft_resource, conversation.projekt_phase, label_id
      )

      return Whatsapp::Flows::AskDraftChoiceService.category(conversation:) if !assigned

      complete_draft
    end

    def assign_sentiment(sentiment_id)
      return stash_draft_choice(:sentiment_id, sentiment_id.to_i) if pre_creation_draft?

      assigned = Whatsapp::DraftSentiment.assign(
        conversation.draft_resource, conversation.projekt_phase, sentiment_id
      )

      return Whatsapp::Flows::AskDraftChoiceService.sentiment(conversation:) if !assigned

      complete_draft
    end

    def pre_creation_draft?
      conversation.draft_resource.blank? && conversation.context["draft_data"].present?
    end

    # Written back through the same key the generation call filled, so
    # DraftCategory and DraftSentiment re-validate the answer against the phase
    # exactly as it validated the model's.
    def stash_draft_choice(key, value)
      draft_data = conversation.context["draft_data"].to_h.merge(key.to_s => value)
      conversation.merge_context!(draft_data: draft_data)

      complete_draft
    end

    def complete_draft
      Whatsapp::Flows::CompleteDraftService.for_first_draft(conversation:, inbound_message_id:)
    end

    # A failed publish leaves the draft intact, so retrying means publishing
    # again; a failed draft leaves nothing behind but the text it was built from.
    #
    # A stored correction is preferred over the original idea: what failed was the
    # edit, and re-drafting from the idea instead would silently throw away the
    # change the citizen asked for. Cleared whenever a first draft is built, so it
    # cannot be re-applied to a draft it never belonged to.
    def retry_last_action
      return publish if conversation.step == "awaiting_draft_decision" &&
                        conversation.draft_resource.present?

      last_correction = conversation.context["last_correction"]

      if last_correction.present?
        return if refuse_if_not_permitted

        return Whatsapp::Flows::BuildDraftService.from_revision(
          conversation:, correction: last_correction, inbound_message_id:
        )
      end

      last_idea_text = conversation.context["last_idea_text"]

      if last_idea_text.present?
        return if refuse_if_not_permitted

        return Whatsapp::Flows::BuildDraftService.from_idea(
          conversation:, idea_text: last_idea_text, inbound_message_id:
        )
      end

      Whatsapp::Flows::HelpService.call(conversation:)
    end

    def dispatch_step
      case conversation.step
      when "awaiting_idea"
        handle_idea
      when "awaiting_category"
        Whatsapp::Flows::AskDraftChoiceService.category(conversation:)
      when "awaiting_sentiment"
        Whatsapp::Flows::AskDraftChoiceService.sentiment(conversation:)
      when "awaiting_duplicate_decision"
        reask_duplicate_choice
      when "awaiting_draft_decision"
        handle_draft_decision
      when "awaiting_image_choice"
        handle_image_choice
      when "awaiting_image_upload"
        handle_image_upload
      when "awaiting_location"
        handle_location
      when "awaiting_final_confirmation"
        handle_final_confirmation
      when "awaiting_revision"
        handle_revision
      when "awaiting_comment"
        Whatsapp::Flows::CreateCommentService.call(conversation:, body: inbound_text)
      when "awaiting_notification_settings"
        Whatsapp::Flows::NotificationSettingsService.call(conversation:)
      when "awaiting_unlink_confirmation"
        Whatsapp::Flows::UnlinkService.ask(conversation:)
      when "awaiting_resume_decision"
        Whatsapp::Flows::ResumeOrRestartService.call(conversation:)
      else
        handle_idle_message
      end
    end

    # Nothing in progress and nothing the assistant could route. An unlinked
    # guest submitter reaches here too, and the menu answers them with the help
    # list rather than three buttons they mostly cannot use.
    def handle_idle_message
      Whatsapp::Flows::MainMenuService.greeting(conversation:)
    end

    def handle_idea
      idea_text = inbound_text.to_s.strip

      if idea_text.blank?
        return Whatsapp::Outbound.recovery(
          conversation:,
          body: Whatsapp.phrase("whatsapp.bot.idea_missing"),
          actions: [:cancel]
        )
      end

      return if refuse_if_not_permitted

      Whatsapp::Flows::BuildDraftService.from_idea(
        conversation:, idea_text: idea_text, inbound_message_id:
      )
    end

    # Checked again per action rather than once at flow entry: the same three
    # steps can be minutes or days apart, and a phase that expires in between
    # must stop an idea before it costs a draft and stop a draft before it
    # becomes a proposal.
    def refuse_if_not_permitted
      permission_problem =
        Whatsapp::Drafting::ResourceCreationValidationService.call(
          projekt_phase: conversation.projekt_phase,
          user: submission_author
        )

      return false if permission_problem.blank?

      Whatsapp::Flows::RefuseParticipationService.call(conversation:, reason: permission_problem)

      true
    end

    # The typed form of the draft card's publish pill, and it has to enter the
    # same steps: a citizen who writes "ja" instead of tapping must still be
    # offered the picture and the pin, not published straight past both. Both
    # questions answer for themselves when their phase has them switched off.
    def handle_draft_decision
      case draft_decision.verdict
      when :publish then ask_image
      when :revise then revise_with(draft_decision.correction)
      else Whatsapp::Flows::PresentDraftService.first_draft(conversation:)
      end
    end

    # The same "ja" that publishes from the draft card publishes from the
    # preview, and the same "nein" still means "change it". The preview carries
    # a revise pill of its own, so this is the typed shortcut rather than the
    # only way back into the loop.
    def handle_final_confirmation
      case draft_decision.verdict
      when :publish then ask_location
      when :revise then revise_with(draft_decision.correction)
      else confirm_submission
      end
    end

    # Every typed answer at these steps is read by the model — "ja" pays the
    # same completion as "passt so, aber der Titel ist zu lang". Before it
    # existed, anything off a fixed list fell through to re-sending the same
    # card, which reads as the bot ignoring what was written.
    #
    # Asked once per message. No two of the three steps that consult it are ever
    # reached by one inbound message, so a second call could only pay for the
    # same verdict.
    def draft_decision
      @draft_decision ||= Whatsapp::AiAssistant::DraftDecisionService.call(
        conversation: conversation, inbound_text: inbound_text
      )
    end

    # The change the citizen already named, applied at once rather than asked for
    # again: "ja aber der Titel ist zu lang" has said everything the revision
    # needs, and answering it with "what should I change?" asks them to repeat
    # themselves. Where they named none, that question is still the way forward.
    def revise_with(correction)
      return ask_revision if correction.blank?

      apply_revision(correction)
    end

    # The step it was asked from is recorded before it is overwritten. A citizen
    # who answers the revision question with "doch, passt so" rejoins the flow
    # where they left it, and the draft card and the preview leave it in
    # different places — one still owes a picture, the other has already sent it.
    def ask_revision
      conversation.merge_context!(revision_origin: conversation.step)
      conversation.update!(step: "awaiting_revision")

      send_revision_question
    end

    def send_revision_question
      Whatsapp::Outbound.text(
        account:,
        body: Whatsapp.phrase("whatsapp.bot.proposal.ask_revision")
      )
    end

    # The step exists to collect a correction, so the citizen's own words are
    # taken as one and the model is asked only the narrower question of whether
    # they changed their mind instead. "doch egal, passt so" and "ach, lass es
    # wie es ist" used to be handed to the rewriter as instructions, spending a
    # generation to alter a draft nobody had asked to alter.
    #
    # The extracted correction is deliberately not used here, only the verdict:
    # this step already asked "what should I change?", so the whole message is
    # the answer, and narrowing it to what a model read out of it could drop half
    # of what the citizen wrote.
    def handle_revision
      correction = inbound_text.to_s.strip

      return send_revision_question if correction.blank?
      return resume_after_revision if draft_decision.verdict == :publish

      apply_revision(correction)
    end

    # Back where the revision question was asked from: the draft card owes the
    # picture and the pin, the preview only the pin. A missing origin — a
    # conversation that was already at this step when the recording was added —
    # takes the longer way round, which can ask for a picture that is already
    # attached but cannot publish anything the citizen has not seen.
    def resume_after_revision
      return ask_location if conversation.context["revision_origin"] == "awaiting_final_confirmation"

      ask_image
    end

    # Shared by the answer to the revision question and the correction read out of
    # a typed answer at the draft card: both are one change to apply, and the round
    # counter and the permission re-check belong to the revision itself rather than
    # to whichever step happened to collect it.
    #
    # The correction is passed on its own. It used to be appended to the citizen's
    # original idea and the whole draft written again from the pair, which meant
    # every round rewrote text they had already approved.
    def apply_revision(correction)
      return if refuse_if_not_permitted

      conversation.update!(revisions_count: conversation.revisions_count + 1)

      Whatsapp::Flows::BuildDraftService.from_revision(
        conversation:, correction: correction, inbound_message_id:
      )
    end

    # The picture is offered between confirming the draft and publishing it, so
    # the permission re-check moves here: refusing after a citizen has already
    # chosen and uploaded an image would waste the one thing they had to do
    # work for.
    #
    # A phase with title images switched off has nothing to ask, so it publishes
    # on the spot — exactly what the skip pill does. Asking anyway would offer a
    # picture the resource cannot carry.
    def ask_image
      return ask_location if !conversation.image_question_available?
      return if refuse_if_not_permitted

      Whatsapp::Flows::AskImageService.call(conversation:)
    end

    # A WhatsApp button stays tappable forever, so this one is reachable long
    # after the submission it belonged to was published. Opening the picker then
    # would take a pin nothing is waiting for — it arrives at an idle step and is
    # dropped — so a finished flow is restarted instead, the same answer
    # confirm_submission gives a draft that is gone.
    def share_location
      return restart_flow if conversation.draft_resource.blank?

      Whatsapp::Flows::AskLocationService.request(conversation:)
    end

    # The pin is the last thing asked, after the picture: a citizen who has just
    # uploaded a photo should not be interrupted twice before their submission
    # goes in. A phase with the map switched off publishes on the spot, exactly
    # as it did before this step existed.
    def ask_location
      return publish if !conversation.location_question_available?
      return if refuse_if_not_permitted

      Whatsapp::Flows::AskLocationService.ask(conversation:)
    end

    # A shared pin publishes, and so does a citizen saying there will not be one:
    # "die adresse weiß ich nicht" used to reach the same place by counting as
    # the one permitted miss, which spent a reminder to arrive at the answer they
    # had already given.
    #
    # Anything else is the citizen answering with words where the picker was
    # expected, so the picker is sent once more — and the second miss publishes
    # without a pin, because the pin is optional and a finished submission must
    # not be held for it.
    def handle_location
      return attach_location if inbound_location.present?
      return publish if Whatsapp::AiAssistant::SkipIntentService.for_location(inbound_text:)
      return publish if conversation.context["location_reminded"].present?

      Whatsapp::Flows::AskLocationService.remind(conversation:)
    end

    # Asked once per message. The two picture steps are never both reached by one
    # inbound message, so a second call could only pay for the same answer.
    def image_skipped_in_words?
      return @image_skipped_in_words if defined?(@image_skipped_in_words)

      @image_skipped_in_words =
        Whatsapp::AiAssistant::SkipIntentService.for_image(inbound_text:)
    end

    def attach_location
      attached = Whatsapp::Flows::AttachSharedLocationService.call(
        conversation:,
        latitude: inbound_location["latitude"],
        longitude: inbound_location["longitude"]
      )

      if attached
        Whatsapp::Outbound.text(
          account:,
          body: Whatsapp.phrase("whatsapp.bot.proposal.location_received")
        )
      end

      publish
    end

    def ask_image_upload
      conversation.update!(step: "awaiting_image_upload")

      send_upload_prompt("whatsapp.bot.proposal.image_upload_prompt")
    end

    # The picture question answered in words. Both this step and the upload step
    # below carry a skip pill and understood nothing but the pill, so "kein foto"
    # was answered by asking for the photo again — which is the one reply that
    # cannot be read as anything but a refusal.
    def handle_image_choice
      return ask_location if image_skipped_in_words?

      ask_image
    end

    # A photo sent while the bot is waiting for one, or the citizen saying there
    # will not be one. Anything else at this step is answered by asking again
    # rather than by silently publishing without the picture they said they
    # wanted to send.
    def handle_image_upload
      return ask_location if inbound_image_id.blank? && image_skipped_in_words?

      return send_upload_prompt("whatsapp.bot.proposal.image_upload_prompt") if
        inbound_image_id.blank?

      attached = Whatsapp::Flows::AttachUploadedImageService.call(
        conversation:, media_id: inbound_image_id
      )

      return send_upload_prompt("whatsapp.bot.proposal.image_failed") if !attached

      Whatsapp::Outbound.text(
        account:,
        body: Whatsapp.phrase("whatsapp.bot.proposal.image_received")
      )

      confirm_submission
    end

    # Every prompt at this step carries the same way out, so the citizen is
    # never stuck waiting to be asked for a photo they cannot send.
    #
    # The rights notice is joined here rather than written into each prompt, so
    # the ask, the re-ask and the failure all carry it by construction. Plain
    # I18n.t like the consent line: telling someone what they are responsible
    # for is not a sentence to hand to the rephraser.
    def send_upload_prompt(body_key)
      body = [
        Whatsapp.phrase(body_key),
        I18n.t("whatsapp.bot.proposal.image_rights_notice")
      ].join("\n\n")

      Whatsapp::Outbound.buttons(
        account: account,
        body: body,
        buttons: [
          Whatsapp::FlowActions.button(
            action: :image_skip, label_key: "whatsapp.bot.buttons.image_skip"
          )
        ]
      )
    end

    # Generation is a slow external call, so the citizen is told it started and
    # the typing bubble covers the wait. A failure goes on anyway: the picture
    # was optional, and losing the proposal over it would be the worse outcome.
    def generate_image_then_confirm
      Whatsapp::Outbound.text(
        account:,
        body: Whatsapp.phrase("whatsapp.bot.proposal.image_generating")
      )
      Whatsapp::Outbound.typing(message_id: inbound_message_id)

      generated = Whatsapp::Flows::GenerateProposalImageService.call(conversation:)

      if !generated
        Whatsapp::Outbound.text(
          account:,
          body: Whatsapp.phrase("whatsapp.bot.proposal.image_generate_failed")
        )
      end

      confirm_submission
    end

    # Only the two paths that produced a picture stop here. "Ohne Bild
    # einreichen" says what it does and publishes on the tap: a preview of a
    # draft the citizen approved two messages ago, with nothing new on it,
    # would be a confirmation of nothing.
    #
    # A draft that is gone by the time the step is reached — a retention purge,
    # an admin deleting the phase — restarts rather than being previewed. The
    # preview reads the record's title and picture, so without this the step
    # raises on every message and the conversation can never leave it.
    def confirm_submission
      return restart_flow if conversation.draft_resource.blank?
      return if refuse_if_not_permitted

      Whatsapp::Flows::ConfirmSubmissionService.call(conversation:)
    end

    def publish
      return if refuse_if_not_permitted

      Whatsapp::Flows::PublishResultService.call(conversation:, inbound_message_id:)
    end

    # Stores what a QR deep link points at without sending anything, so the
    # caller decides the reply (the login link first for unlinked numbers).
    # Returns nil, :phase, :projekt, :projekt_choice or :projekt_without_phase.
    def capture_entry_token
      capture_phase_token || capture_projekt_token
    end

    def capture_phase_token
      projekt_phase_id = Whatsapp::QrToken.projekt_phase_id_from(inbound_text)

      return if projekt_phase_id.blank?

      projekt_phase = ::ProjektPhase.find_by(id: projekt_phase_id)

      return if projekt_phase.blank?

      conversation.start_flow!(projekt_phase)

      :phase
    end

    def capture_projekt_token
      projekt_id = Whatsapp::QrToken.projekt_id_from(inbound_text)

      return if projekt_id.blank?

      projekt = ::Projekt.find_by(id: projekt_id)

      return if projekt.blank?

      store_projekt_entry(projekt)
    end

    def store_projekt_entry(projekt)
      eligible_phases = Whatsapp::EligiblePhasesQuery.call(projekt: projekt)

      return :projekt_without_phase if eligible_phases.empty?

      if eligible_phases.one?
        conversation.start_flow!(eligible_phases.first)

        return :projekt
      end

      conversation.reset_flow!
      @entry_projekt = projekt

      :projekt_choice
    end

    def entry_projekt
      @entry_projekt
    end

    # The wamid of the message being answered. WhatsApp ties a typing indicator
    # to one inbound message, so the slow paths need it to show the bubble.
    def inbound_message_id
      @whatsapp_message.wa_message_id
    end

    def button_reply_id
      @raw_message.dig("interactive", "button_reply", "id") ||
        @raw_message.dig("button", "payload")
    end

    def inbound_image_id
      @raw_message.dig("image", "id")
    end

    # The coordinates as WhatsApp's picker sent them, alongside an optional name
    # and address the flow has no use for — the pin is what a map renders.
    def inbound_location
      @raw_message["location"]
    end

    def list_reply_id
      @raw_message.dig("interactive", "list_reply", "id")
    end

    def normalized_text
      @normalized_text ||= inbound_text.to_s.strip.downcase
    end

    def inbound_text
      return @inbound_text if defined?(@inbound_text)

      @inbound_text =
        if @whatsapp_message.audio?
          transcribed_text
        else
          @whatsapp_message.body
        end
    end

    def transcribed_text
      transcript = Whatsapp::Inbound::TranscribeVoiceService.call(media_id: @raw_message.dig("audio", "id"))

      if transcript.blank?
        Whatsapp::Outbound.recovery(
          conversation:,
          body: Whatsapp.phrase("whatsapp.bot.transcription_failed"),
          actions: [:cancel]
        )

        return nil
      end

      @whatsapp_message.update!(body: transcript)

      transcript
    end
end
