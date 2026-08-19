# Dispatch-parity harness for Whatsapp::Inbound::ProcessMessageService — the
# regression net for a stack without a test suite. It stubs the outbound
# senders and every model-call seam (router, classifier, transcription,
# eligibility), feeds a fixed ~200-case input matrix through the inbound gate
# chain, and prints one line per case: which flow entry point was invoked,
# with which arguments, and the conversation state left behind. Everything
# runs inside a rolled-back transaction; nothing persists and nothing is
# actually sent.
#
# Usage — before touching the gate chain, the dispatch tables, or anything
# they route to:
#
#   bin/rails runner script/whatsapp_dispatch_parity.rb > /tmp/parity_before.txt
#   ... make the change ...
#   bin/rails runner script/whatsapp_dispatch_parity.rb > /tmp/parity_after.txt
#   diff /tmp/parity_before.txt /tmp/parity_after.txt   # must be empty
#
# An intended behavior change shows up as a readable diff of exactly the
# affected cases — review it, then keep the new output as the baseline.
#
# Requires a dev DB with at least two projekt phases, one projekt, one
# proposal, and one user. Script-only metaprogramming — the
# no-metaprogramming house rule binds app code, not verification scripts.

abort("dev only: this script monkey-patches app classes") if !Rails.env.development?

RECORDER = []
SCRIPT = {}

def format_value(value)
  return "#{value.class.name}##{value.id}" if value.is_a?(ActiveRecord::Base)

  value.inspect
end

def format_kwargs(kwargs)
  interesting = kwargs.except(:conversation, :inbound_message_id)

  return "" if interesting.empty?

  "(" + interesting.sort.map { |key, value| "#{key}=#{format_value(value)}" }.join(" ") + ")"
end

# --- seams -------------------------------------------------------------

Whatsapp.define_singleton_method(:enabled?) { true }

# Leaf senders record; question/recovery stay REAL so the pending-question
# write still happens and shows up in the ctx suffix.
[:text, :buttons, :buttons_with_media_header, :buttons_with_picture, :list, :typing].each do |sender|
  Whatsapp::Send.define_singleton_method(sender) do |**kwargs|
    ids = Array(kwargs[:buttons] || kwargs[:rows]).map { |row| row[:id] }.join(",")

    RECORDER << (ids.empty? ? "Send.#{sender}" : "Send.#{sender}[#{ids}]")

    true
  end
end

FLOW_STUBS = {
  "OnboardingGreetingService" => [:first_contact, :disclose, :welcome_back],
  "SendLoginLinkService" => [:call, :after_switch],
  "LinkOutcomeService" => [:declined],
  "DiscoveryService" => [:linked, :unlinked],
  "BrowseProjektsService" => [:call, :category],
  "SubmitProposalService" => [:call],
  "ContributionsService" => [:call],
  "MainMenuService" => [:greeting],
  "NotificationSettingsService" => [:call, :toggle],
  "UnlinkService" => [:ask, :confirm],
  "AskDraftChoiceService" => [:category, :sentiment, :assign_category, :assign_sentiment],
  "ProposalImageService" => [:ask, :ask_upload, :generate, :handle_choice, :handle_upload],
  "AskLocationService" => [:ask, :request, :remind, :handle_answer],
  "PublishResultService" => [:call],
  "AskRevisionService" => [:ask, :re_ask, :handle_answer],
  "AskDuplicateChoiceService" => [:submit_anyway, :support_instead, :handle_answer],
  "ResumeOrRestartService" => [:call, :resume, :restart],
  "SupportService" => [:register],
  "AskIdeaService" => [:call, :handle_answer],
  "PresentDraftService" => [:handle_decision],
  "ConfirmSubmissionService" => [:handle_decision],
  "CommentService" => [:prompt, :create],
  "BuildDraftService" => [:from_idea, :from_revision, :from_accepted_idea],
  "CancelService" => [:call],
  "MessageDeliveryService" => [:disable, :enable],
  "SendProjektCardService" => [:call],
  "StartPhaseFlowService" => [:call],
  "RefuseParticipationService" => [:call],
  "ProposalPromptService" => [:call]
}.freeze

# const_get rather than a rescue: a service renamed out from under this list is
# the harness silently losing a stub, and a lost stub means the real service runs
# and the case is measuring something else. HelpService was exactly that — it had
# been folded into MainMenuService.greeting and the list still named it, which
# aborted every run.
FLOW_STUBS.each do |name, entry_points|
  klass = Whatsapp::Flows.const_get(name)

  entry_points.each do |entry_point|
    klass.define_singleton_method(entry_point) do |**kwargs|
      RECORDER << "#{name}.#{entry_point}#{format_kwargs(kwargs)}"

      true
    end
  end
end

Whatsapp::AiAssistant::RouterService.define_singleton_method(:call) do |**|
  SCRIPT[:router] || ServiceResult.failure(error: "unscripted router")
end

Whatsapp::AiAssistant::MessageIntentService.define_singleton_method(:call) do |**|
  SCRIPT[:intent] || ServiceResult.success(verdict: :answer, correction: nil)
end

Whatsapp::Inbound::TranscribeVoiceService.define_singleton_method(:call) do |**|
  SCRIPT[:transcript]
end

# Nil is "the composer would not vouch for this", which every caller answers by
# sending the fixed locale copy — so the bodies below stay the deterministic ones
# this harness diffs. Stubbed rather than left to ai_available?, which defaults to
# true here: unstubbed, every one of the ~200 cases pays a live completion for a
# wording no assertion reads. Conversation quality is the other harness's job
# (script/whatsapp_conversation_scenarios.rb), which exists to run these for real.
Whatsapp::AiAssistant::ComposeReplyService.define_singleton_method(:call) do |**|
  SCRIPT[:composed]
end

Ai::Settings.define_singleton_method(:ai_available?) { SCRIPT.fetch(:ai, true) }

Whatsapp::EligiblePhasesQuery.define_singleton_method(:eligible?) do |projekt_phase|
  SCRIPT.fetch(:eligible, true) && projekt_phase.present?
end

# `**` rather than a named keyword: the query is called both with a projekt and
# without one (ProjektParticipationService#open_phases), and a stub that made the
# keyword required turned every participation case into "missing keyword: :projekt"
# instead of a dispatch. A stub's arity has to be at least as permissive as the
# method it stands in for.
Whatsapp::EligiblePhasesQuery.define_singleton_method(:call) do |**|
  SCRIPT.fetch(:eligible_phases, [])
end

ProjektPhase.class_eval do
  def guest_participation?
    SCRIPT.fetch(:guest, false)
  end
end

Whatsapp::Account.class_eval do
  def awaiting_link?
    SCRIPT.fetch(:awaiting_link, false)
  end

  def greeted?
    SCRIPT.fetch(:greeted, true)
  end
end

# --- fixtures ----------------------------------------------------------

PHASE = ProjektPhase.order(:id).first || raise("need a projekt phase")
PHASE2 = ProjektPhase.order(:id).offset(1).first || raise("need two phases")
PROJEKT = Projekt.order(:id).first || raise("need a projekt")
PROPOSAL = Proposal.unscoped.order(:id).first || raise("need a proposal")
LINKED_USER = User.order(:id).first || raise("need a user")

$sequence = 0
ACCOUNTS = {}

# The linked slot takes over whatever account already owns LINKED_USER instead of
# adding a second one. whatsapp_accounts.user_id is unique, so on any database
# where that user has been linked before — a smoke test, a manual walkthrough —
# creating one raised RecordNotUnique and every `linked` case in the matrix
# reported the violation in place of a dispatch. Taking it over is safe: the run
# is one rolled-back transaction.
def find_or_create_account(linked)
  return Whatsapp::Account.find_or_create_by!(user_id: LINKED_USER.id) do |account|
    account.wa_id = next_parity_wa_id
    account.phone = "+#{account.wa_id}"
    account.opt_in_at = Time.current
  end if linked

  wa_id = next_parity_wa_id

  Whatsapp::Account.create!(
    wa_id: wa_id, phone: "+#{wa_id}", opt_in_at: Time.current, user: nil
  )
end

def next_parity_wa_id
  $sequence += 1

  "49900#{format('%06d', $sequence)}"
end

# One account per linkage kind (the user_id unique index allows only one
# linked account); trait columns are reset per case.
def build_account(traits)
  key = traits[:linked] ? :linked : :unlinked

  account = ACCOUNTS[key] ||= find_or_create_account(traits[:linked])

  # Reset every column a flow can stamp, not just the ones a trait names: the
  # account rows are memoized across cases, so a column left alone carries one
  # case's side effect into every case after it and the run stops being
  # reproducible. terms_accepted_at is stamped by TermsConsentService#accept and
  # belongs to that set for the same reason ai_disclosed_at does.
  account.update!(
    ai_disclosed_at: traits[:undisclosed] ? nil : Time.current,
    opt_out_at: traits[:opted_out] ? 1.day.ago : nil,
    terms_accepted_at: traits[:consented] ? Time.current : nil
  )

  account
end

def tap_raw(reply_id)
  { "interactive" => { "button_reply" => { "id" => reply_id, "title" => "x" } } }
end

def list_raw(reply_id)
  { "interactive" => { "list_reply" => { "id" => reply_id, "title" => "x" } } }
end

def run_case(name, kind:, raw:, body: nil, account_traits: {}, conversation_traits: {}, script: {})
  RECORDER.clear
  SCRIPT.clear
  SCRIPT.merge!(script)

  # Savepoint per case, so one failing case cannot poison the rest of the run.
  ActiveRecord::Base.transaction(requires_new: true) do
    account = build_account(account_traits)
    conversation = account.conversation
    attributes = { step: conversation_traits[:step] || "idle" }
    attributes[:projekt_phase] = conversation_traits[:projekt_phase]
    attributes[:draft_resource] = conversation_traits[:draft_resource]
    attributes[:context] = conversation_traits[:context] || {}
    conversation.update!(attributes)

    $sequence += 1
    message = Whatsapp::Message.create!(
      whatsapp_account: account,
      direction: "inbound",
      kind: kind,
      body: body,
      wa_message_id: "wamid.parity.#{$sequence}",
      sent_at: Time.current
    )

    Whatsapp::Inbound::ProcessMessageService.call(whatsapp_message: message, raw_message: raw)

    conversation.reload
    state = "step=#{conversation.step} phase=#{conversation.projekt_phase_id.present?} " \
            "draft=#{conversation.draft_resource_id.present?} ctx=#{conversation.context.keys.sort.join(",")}"

    puts "CASE #{name} => #{RECORDER.join(" | ")} ;; #{state}"
  end
rescue StandardError => e
  puts "CASE #{name} => ERROR #{e.class}: #{e.message}"
end

# --- matrix ------------------------------------------------------------

ActiveRecord::Base.transaction do
  action_params = {
    idea_start: PHASE.id, category: 5, sentiment: 7, view_projekt: PROJEKT.id,
    support: PROPOSAL.id, support_instead: PROPOSAL.id, notify_toggle: "new_projekt"
  }

  Whatsapp::FlowActions::ACTIONS.each do |action|
    reply_id = Whatsapp::FlowActions.id_for(action: action, param: action_params[action])

    [
      ["linked", { linked: true }, {}],
      ["unlinked", {}, {}],
      ["unlinked_guest", {}, { guest: true }]
    ].each do |label, traits, extra_script|
      run_case("flow_action:#{action}:#{label}",
        kind: "interactive", body: "x", raw: tap_raw(reply_id),
        account_traits: traits,
        conversation_traits: { projekt_phase: PHASE },
        script: extra_script)
    end
  end

  run_case("flow_action:view_projekt:missing", kind: "interactive", body: "x",
    raw: tap_raw(Whatsapp::FlowActions.id_for(action: :view_projekt, param: 999_999)),
    account_traits: { linked: true })

  run_case("flow_action:idea_start:ineligible", kind: "interactive", body: "x",
    raw: tap_raw(Whatsapp::FlowActions.id_for(action: :idea_start, param: PHASE.id)),
    account_traits: { linked: true }, script: { eligible: false })

  run_case("flow_action:stale_pill", kind: "interactive", body: "x",
    raw: tap_raw("whatsapp_flow_no_such_action"), account_traits: { linked: true },
    script: { router: ServiceResult.success(outcome: :answered) })

  run_case("recovery:help", kind: "interactive", body: "x", raw: tap_raw("whatsapp_help"),
    account_traits: { linked: true })
  run_case("recovery:cancel", kind: "interactive", body: "x", raw: tap_raw("whatsapp_cancel"),
    account_traits: { linked: true })
  run_case("recovery:retry:publish", kind: "interactive", body: "x", raw: tap_raw("whatsapp_retry"),
    account_traits: { linked: true },
    conversation_traits: { step: "awaiting_draft_decision", draft_resource: PROPOSAL })
  run_case("recovery:retry:correction", kind: "interactive", body: "x", raw: tap_raw("whatsapp_retry"),
    account_traits: { linked: true },
    conversation_traits: { context: { "last_correction" => "fix title" } })
  run_case("recovery:retry:idea", kind: "interactive", body: "x", raw: tap_raw("whatsapp_retry"),
    account_traits: { linked: true },
    conversation_traits: { context: { "last_idea_text" => "my idea" } })
  run_case("recovery:retry:nothing", kind: "interactive", body: "x", raw: tap_raw("whatsapp_retry"),
    account_traits: { linked: true })
  run_case("recovery:list_shape", kind: "interactive", body: "x", raw: list_raw("whatsapp_cancel"),
    account_traits: { linked: true })
  run_case("recovery:legacy_button_shape", kind: "interactive", body: "x",
    raw: { "button" => { "payload" => "whatsapp_cancel", "text" => "x" } },
    account_traits: { linked: true })

  Whatsapp::Conversation::Step.constants.sort.each do |step_constant|
    step = Whatsapp::Conversation::Step.const_get(step_constant)

    run_case("step:#{step}:text",
      kind: "text", body: "hallo welt", raw: { "text" => { "body" => "hallo welt" } },
      account_traits: { linked: true },
      conversation_traits: {
        step: step, projekt_phase: PHASE,
        context: { "flow_started_at" => Time.current.iso8601 }
      },
      script: { router: ServiceResult.success(outcome: :flow, decision: :answer, correction: nil) })
  end

  %w[
    awaiting_draft_decision awaiting_image_choice awaiting_image_upload
    awaiting_location awaiting_final_confirmation awaiting_revision
  ].each do |step|
    [[:publish, nil], [:revise, "mach es kuerzer"], [:skip, nil]].each do |verdict, correction|
      run_case("verdict:#{step}:#{verdict}:handoff",
        kind: "text", body: "ja gut", raw: { "text" => { "body" => "ja gut" } },
        account_traits: { linked: true },
        conversation_traits: {
          step: step, projekt_phase: PHASE,
          context: { "flow_started_at" => Time.current.iso8601 }
        },
        script: { router: ServiceResult.success(outcome: :flow, decision: verdict, correction: correction) })

      run_case("verdict:#{step}:#{verdict}:classifier_guest",
        kind: "text", body: "ja gut", raw: { "text" => { "body" => "ja gut" } },
        conversation_traits: {
          step: step, projekt_phase: PHASE,
          context: { "flow_started_at" => Time.current.iso8601 }
        },
        script: { guest: true, intent: ServiceResult.success(verdict: verdict, correction: correction) })
    end
  end

  run_case("stop:drafting", kind: "text", body: "Stopp", raw: { "text" => { "body" => "Stopp" } },
    account_traits: { linked: true },
    conversation_traits: {
      step: "awaiting_idea", projekt_phase: PHASE,
      context: { "flow_started_at" => Time.current.iso8601 }
    })
  run_case("stop:idle", kind: "text", body: "STOP", raw: { "text" => { "body" => "STOP" } },
    account_traits: { linked: true })

  run_case("intent:opt_out:active_unlinked", kind: "text", body: "keine nachrichten mehr",
    raw: { "text" => { "body" => "keine nachrichten mehr" } },
    script: { intent: ServiceResult.success(verdict: :opt_out, correction: nil) })
  run_case("intent:opt_out:already_out", kind: "text", body: "keine nachrichten mehr",
    raw: { "text" => { "body" => "keine nachrichten mehr" } },
    account_traits: { opted_out: true },
    script: { intent: ServiceResult.success(verdict: :opt_out, correction: nil) })
  run_case("intent:opt_in:opted_out", kind: "text", body: "wieder anmelden",
    raw: { "text" => { "body" => "wieder anmelden" } },
    account_traits: { opted_out: true },
    script: { intent: ServiceResult.success(verdict: :opt_in, correction: nil) })
  run_case("intent:opt_in:active", kind: "text", body: "wieder anmelden",
    raw: { "text" => { "body" => "wieder anmelden" } },
    script: { intent: ServiceResult.success(verdict: :opt_in, correction: nil) })
  run_case("intent:abort:open_interaction", kind: "text", body: "abbrechen bitte",
    raw: { "text" => { "body" => "abbrechen bitte" } },
    conversation_traits: {
      step: "awaiting_idea", projekt_phase: PHASE,
      context: { "flow_started_at" => Time.current.iso8601 }
    },
    script: { guest: true, intent: ServiceResult.success(verdict: :abort, correction: nil) })
  run_case("intent:abort:idle_no_pending", kind: "text", body: "abbrechen bitte",
    raw: { "text" => { "body" => "abbrechen bitte" } },
    script: { intent: ServiceResult.success(verdict: :abort, correction: nil) })
  run_case("intent:abort:idle_with_pending", kind: "text", body: "abbrechen bitte",
    raw: { "text" => { "body" => "abbrechen bitte" } },
    conversation_traits: { context: { "pending_question" => true } },
    script: { intent: ServiceResult.success(verdict: :abort, correction: nil) })

  run_case("router:answered", kind: "text", body: "was gibt es hier",
    raw: { "text" => { "body" => "was gibt es hier" } }, account_traits: { linked: true },
    script: { router: ServiceResult.success(outcome: :answered) })
  run_case("router:handoff_answer", kind: "text", body: "hallo",
    raw: { "text" => { "body" => "hallo" } }, account_traits: { linked: true },
    script: { router: ServiceResult.success(outcome: :flow, decision: :answer, correction: nil) })
  run_case("router:failure", kind: "text", body: "hallo",
    raw: { "text" => { "body" => "hallo" } }, account_traits: { linked: true },
    script: { router: ServiceResult.failure(error: "boom") })
  run_case("router:ai_off", kind: "text", body: "hallo",
    raw: { "text" => { "body" => "hallo" } }, account_traits: { linked: true },
    script: { ai: false })
  run_case("router:location_skips_router", kind: "location", body: nil,
    raw: { "location" => { "latitude" => 52.5, "longitude" => 13.4 } },
    account_traits: { linked: true },
    conversation_traits: {
      step: "awaiting_location", projekt_phase: PHASE,
      context: { "flow_started_at" => Time.current.iso8601 }
    })

  phase_token = Whatsapp::QrToken.for_projekt_phase(PHASE)
  projekt_token = Whatsapp::QrToken.for_projekt(PROJEKT)

  run_case("qr:phase:linked", kind: "text", body: phase_token,
    raw: { "text" => { "body" => phase_token } }, account_traits: { linked: true })
  run_case("qr:phase:unlinked", kind: "text", body: phase_token,
    raw: { "text" => { "body" => phase_token } })
  run_case("qr:projekt:no_phase", kind: "text", body: projekt_token,
    raw: { "text" => { "body" => projekt_token } }, account_traits: { linked: true },
    script: { eligible_phases: [] })
  run_case("qr:projekt:one_phase", kind: "text", body: projekt_token,
    raw: { "text" => { "body" => projekt_token } }, account_traits: { linked: true },
    script: { eligible_phases: [PHASE] })
  run_case("qr:projekt:many_phases", kind: "text", body: projekt_token,
    raw: { "text" => { "body" => projekt_token } }, account_traits: { linked: true },
    script: { eligible_phases: [PHASE, PHASE2] })
  run_case("qr:tampered", kind: "text", body: "#{phase_token[0..-2]}0",
    raw: { "text" => { "body" => "#{phase_token[0..-2]}0" } }, account_traits: { linked: true },
    script: { router: ServiceResult.success(outcome: :answered) })

  run_case("audio:transcribed", kind: "audio", body: nil,
    raw: { "audio" => { "id" => "media1" } }, account_traits: { linked: true },
    script: { transcript: "hallo welt", router: ServiceResult.success(outcome: :answered) })
  run_case("audio:transcribed_stop", kind: "audio", body: nil,
    raw: { "audio" => { "id" => "media1" } }, account_traits: { linked: true },
    conversation_traits: {
      step: "awaiting_idea", projekt_phase: PHASE,
      context: { "flow_started_at" => Time.current.iso8601 }
    },
    script: { transcript: "stopp" })
  run_case("audio:failed:linked", kind: "audio", body: nil,
    raw: { "audio" => { "id" => "media1" } }, account_traits: { linked: true },
    script: { transcript: nil })
  run_case("audio:failed:opted_out", kind: "audio", body: nil,
    raw: { "audio" => { "id" => "media1" } }, account_traits: { opted_out: true },
    script: { transcript: nil })
  run_case("audio:failed:first_contact", kind: "audio", body: nil,
    raw: { "audio" => { "id" => "media1" } },
    script: { transcript: nil, greeted: false })

  run_case("unlinked:awaiting_link", kind: "text", body: "hallo",
    raw: { "text" => { "body" => "hallo" } }, script: { awaiting_link: true })
  run_case("unlinked:welcome_back", kind: "text", body: "hallo",
    raw: { "text" => { "body" => "hallo" } })
  run_case("first_contact:welcome_kind", kind: "welcome", body: nil, raw: {},
    script: { greeted: false })
  run_case("first_contact:plain_text", kind: "text", body: "hallo",
    raw: { "text" => { "body" => "hallo" } }, script: { greeted: false })
  run_case("disclosure:undisclosed_linked", kind: "text", body: "hallo",
    raw: { "text" => { "body" => "hallo" } },
    account_traits: { linked: true, undisclosed: true },
    script: { router: ServiceResult.success(outcome: :answered) })

  # CON-2969. The consent gate itself lives inside AskIdeaService#call, which is
  # stubbed here like every other flow entry point — what these cases pin is the
  # dispatch either side of it: which service each new pill reaches, and that a
  # message arriving on the new step re-asks the question instead of being read
  # as the Beitrag. The gate's own branch is verified against the unstubbed
  # service, not here.
  [["no_consent", {}], ["consented", { consented: true }]].each do |label, consent_traits|
    [:terms_accept, :terms_decline].each do |action|
      run_case("consent:pill:#{action}:#{label}",
        kind: "interactive", body: "x",
        raw: tap_raw(Whatsapp::FlowActions.id_for(action: action)),
        account_traits: { linked: true }.merge(consent_traits),
        conversation_traits: {
          step: "awaiting_terms_consent", projekt_phase: PHASE,
          context: { "flow_started_at" => Time.current.iso8601 }
        })
    end

    run_case("consent:step:text:#{label}",
      kind: "text", body: "mehr baenke am rummelgang",
      raw: { "text" => { "body" => "mehr baenke am rummelgang" } },
      account_traits: { linked: true }.merge(consent_traits),
      conversation_traits: {
        step: "awaiting_terms_consent", projekt_phase: PHASE,
        context: { "flow_started_at" => Time.current.iso8601 }
      },
      script: { router: ServiceResult.success(outcome: :flow, decision: :answer, correction: nil) })
  end

  # Accepting with no phase on the conversation: AskIdeaService is what refuses
  # it, so the pill must still be dispatched rather than guarded here.
  run_case("consent:pill:terms_accept:no_phase", kind: "interactive", body: "x",
    raw: tap_raw(Whatsapp::FlowActions.id_for(action: :terms_accept)),
    account_traits: { linked: true },
    conversation_traits: { step: "awaiting_terms_consent" })

  # Declining from an unlinked number: terms_decline is deliberately outside
  # SUBMISSION_ACTIONS, so it must reach the service instead of a link request.
  run_case("consent:pill:terms_decline:unlinked", kind: "interactive", body: "x",
    raw: tap_raw(Whatsapp::FlowActions.id_for(action: :terms_decline)),
    conversation_traits: { step: "awaiting_terms_consent", projekt_phase: PHASE })

  run_case("stale:drafting", kind: "text", body: "hallo",
    raw: { "text" => { "body" => "hallo" } }, account_traits: { linked: true },
    conversation_traits: {
      step: "awaiting_idea", projekt_phase: PHASE,
      context: { "flow_started_at" => 4000.minutes.ago.iso8601 }
    })
  run_case("stale:resume_decision_not_interrupted", kind: "text", body: "hallo",
    raw: { "text" => { "body" => "hallo" } }, account_traits: { linked: true },
    conversation_traits: {
      step: "awaiting_resume_decision", projekt_phase: PHASE,
      context: { "flow_started_at" => 4000.minutes.ago.iso8601 }
    })

  # CON-2968. A message with no substance while the bot waits on free text is the
  # citizen beginning again rather than the answer: "hallo" at awaiting_idea used
  # to reach AskIdeaService.handle_answer and cost a draft generation. What these
  # cases pin is the dispatch around that reading — the question instead of the
  # content, where each of its two pills lands, and that the question gives up
  # rather than asking forever. ContinueOrRestartService is deliberately not
  # stubbed: which prompt it re-sends is the behavior under test.
  %w[
    awaiting_idea awaiting_comment awaiting_image_upload awaiting_revision awaiting_location
    awaiting_participation_projekt
  ].each do |step|
    run_case("fresh_start:classifier:#{step}",
      kind: "text", body: "hallo", raw: { "text" => { "body" => "hallo" } },
      conversation_traits: {
        step: step, projekt_phase: PHASE,
        context: { "flow_started_at" => Time.current.iso8601 }
      },
      script: { guest: true, intent: ServiceResult.success(verdict: :fresh_start, correction: nil) })
  end

  # The other half of the same reading: a greeting that carries substance is the
  # contribution, and nothing about this gate may touch it.
  run_case("fresh_start:classifier:substance_stays_content",
    kind: "text", body: "hallo, ich moechte mehr baenke am rummelgang",
    raw: { "text" => { "body" => "hallo, ich moechte mehr baenke am rummelgang" } },
    conversation_traits: {
      step: "awaiting_idea", projekt_phase: PHASE,
      context: { "flow_started_at" => Time.current.iso8601 }
    },
    script: { guest: true, intent: ServiceResult.success(verdict: :answer, correction: nil) })

  run_case("fresh_start:reask_exhausted",
    kind: "text", body: "hallo", raw: { "text" => { "body" => "hallo" } },
    conversation_traits: {
      step: "awaiting_continue_decision", projekt_phase: PHASE,
      context: {
        "flow_started_at" => Time.current.iso8601, "interrupted_step" => "awaiting_idea",
        "choice_reasks" => 3
      }
    },
    script: { guest: true, intent: ServiceResult.success(verdict: :fresh_start, correction: nil) })

  [
    ["awaiting_idea", {}],
    ["awaiting_revision", {}],
    ["awaiting_image_upload", {}],
    ["awaiting_location", {}],
    ["awaiting_participation_projekt", {}],
    ["awaiting_comment", { "comment_proposal_id" => PROPOSAL.id }],
    ["awaiting_comment_gone", { "comment_proposal_id" => 999_999 }]
  ].each do |interrupted, extra_context|
    [:continue_flow, :start_over].each do |action|
      run_case("fresh_start:pill:#{action}:#{interrupted}",
        kind: "interactive", body: "x",
        raw: tap_raw(Whatsapp::FlowActions.id_for(action: action)),
        account_traits: { linked: true },
        conversation_traits: {
          step: "awaiting_continue_decision", projekt_phase: PHASE, draft_resource: PROPOSAL,
          context: {
            "flow_started_at" => Time.current.iso8601,
            "interrupted_step" => interrupted.delete_suffix("_gone")
          }.merge(extra_context)
        })
    end
  end

  run_case("fresh_start:pill:continue_flow:no_interrupted_step",
    kind: "interactive", body: "x",
    raw: tap_raw(Whatsapp::FlowActions.id_for(action: :continue_flow)),
    account_traits: { linked: true },
    conversation_traits: {
      step: "awaiting_continue_decision", projekt_phase: PHASE,
      context: { "flow_started_at" => Time.current.iso8601 }
    })

  # Written rather than tapped, with substance: the step the question
  # interrupted is restored and this message answers it (StepDispatch).
  run_case("fresh_start:written_answer_resumes_step",
    kind: "text", body: "mehr baenke am rummelgang",
    raw: { "text" => { "body" => "mehr baenke am rummelgang" } },
    conversation_traits: {
      step: "awaiting_continue_decision", projekt_phase: PHASE,
      context: {
        "flow_started_at" => Time.current.iso8601, "interrupted_step" => "awaiting_idea"
      }
    },
    script: { guest: true, intent: ServiceResult.success(verdict: :answer, correction: nil) })

  raise ActiveRecord::Rollback
end

warn "parity run complete"
