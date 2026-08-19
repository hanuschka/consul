# Conversation-quality harness for the WhatsApp bot — the reading net for
# CON-2982, where what is being checked is how the chat *sounds* and no
# assertion can settle it.
#
# It walks the ticket's own examples as real conversations: the citizen's
# message goes through the whole inbound gate chain, the model calls run for
# real, and what the bot would have sent is printed instead of delivered. The
# elapsed-gap cases are driven by moving the conversation's clock backwards
# rather than by waiting, which is the only way the "minutes / hours / a week"
# branches are walkable in one sitting.
#
# Unlike whatsapp_dispatch_parity.rb, which stubs every model seam so its
# ~200-case output can be diffed byte for byte, this one stubs nothing above the
# transport: the composed wording is the whole point, so the completions have to
# happen. Two consequences — it costs real tokens, and its output is legitimately
# different on every run. Read it; do not diff it.
#
# Usage:
#
#   bin/rails runner script/whatsapp_conversation_scenarios.rb
#   bin/rails runner script/whatsapp_conversation_scenarios.rb 1 3 5   # by number
#
# What to read for, per the acceptance criteria:
#   * scenario 1 — the reply answers "what can I do here" instead of asking it
#     back, and names the options in the text rather than only behind a button
#   * scenarios 3 and 4 — the same words get a re-orientation after a week and a
#     seamless continuation after a minute
#   * scenario 5 — the photo and the location are not asked for again
#   * scenario 6 — the reply picks up the notification the bot itself sent
#   * scenario 10 — the refusal is in the bot's own words and offers what is
#     possible instead
#   * across every scenario — no wording repeats, and no reply reads as though it
#     could stand unchanged somewhere else
#
# Everything runs inside a rolled-back transaction: no contribution is created,
# no message is delivered, no account is left opted out. Script-only
# metaprogramming — the no-metaprogramming house rule binds app code, not
# verification scripts.

abort("dev only: this script monkey-patches app classes") if !Rails.env.development?

SENT = []

# --- transport seam ----------------------------------------------------
#
# Stubbed at the API client rather than at Whatsapp::Send, deliberately: every
# layer above stays real, so the outbound rows still get written — and those rows
# are what Whatsapp::RecentDialogQuery reads to build the dialog digest. Stubbing
# Send would leave the digest empty and quietly disable the very feature
# scenarios 3 and 6 exist to check.

FakeResponse = Struct.new(:message_id) do
  def success?
    true
  end

  def error_payload
    {}
  end
end

# Monotonic across the whole run, never derived from the per-scenario SENT
# buffer: whatsapp_messages.wa_message_id is uniquely indexed, and an id that
# restarts at 1 with each scenario collides on the second one. The resulting
# RecordNotUnique is swallowed by RouterService's own rescue, so what the harness
# showed was a silent "nothing sent" and then a poisoned transaction for every
# scenario after it.
#
# The counter lives in a constant rather than an instance variable. WhatsappApi
# ::Client#messages returns a fresh FakeMessages every call, so an @ivar would be
# set on a receiver that is discarded immediately and the sequence would sit at 1
# forever — leaving SecureRandom as the only thing keeping the ids apart, which is
# not what this says it does.
FAKE_ID_SEQUENCE = [0]

def next_fake_message_id
  FAKE_ID_SEQUENCE[0] += 1

  "wamid.fake.#{SecureRandom.hex(4)}.#{FAKE_ID_SEQUENCE[0]}"
end

class FakeMessages
  SENDERS = {
    send_text: :text,
    send_buttons: :buttons,
    send_buttons_with_media_header: :buttons,
    send_list: :list,
    send_sectioned_list: :list,
    send_location_request: :location_request,
    send_cta_url: :cta_url,
    send_image: :image,
    send_template: :template,
    send_card_template: :template
  }.freeze

  SENDERS.each do |method_name, kind|
    define_method(method_name) do |**kwargs|
      SENT << {
        kind: kind,
        body: kwargs[:body] || kwargs[:caption] || template_body(kwargs),
        options: option_labels(kwargs)
      }

      FakeResponse.new(next_fake_message_id)
    end
  end

  def send_typing_indicator(**)
    FakeResponse.new(next_fake_message_id)
  end

  private

    def template_body(kwargs)
      "[template #{kwargs[:name]}] #{Array(kwargs[:variables]).join(" | ")}"
    end

    def option_labels(kwargs)
      rows = Array(kwargs[:buttons]) +
             Array(kwargs[:sections]).flat_map { |section| Array(section[:rows]) } +
             Array(kwargs[:rows])

      rows.map { |row| row[:title] }
    end
end

WhatsappApi::Client.define_method(:messages) { FakeMessages.new }
Whatsapp.define_singleton_method(:enabled?) { true }

# --- fixtures ----------------------------------------------------------

def open_phase
  @open_phase ||= Whatsapp::EligiblePhasesQuery.uncapped.first ||
                  abort("no phase currently accepting contributions — cannot run the flow cases")
end

# Whether a draft can be generated here at all. ProposalAiDraft::GenerateDraftService
# builds its system instructions from the remote consul_ai_prompts store, so on a
# machine that cannot reach the DT API the whole submission flow answers "das hat
# gerade nicht geklappt" — which reads like a bug in the bot and is not one. The
# scenarios that draft say so up front instead.
def drafting_available?
  return @drafting_available if defined?(@drafting_available)

  DtApi::Client.new(use_cache: true).consul_ai_prompts.get(:proposal_generate_with_ai)

  @drafting_available = true
rescue StandardError => e
  puts "  ~~ drafting unavailable here: #{e.class} — the prompt store is unreachable, so the"
  puts "     submission cases cannot run locally. Check them on staging."

  @drafting_available = false
end

# A linked, already-disclosed, already-consented number, because none of the
# scenarios is about first contact: without this every one of them would be
# answered by the onboarding greeting instead of by the reply being checked.
#
# `greeted?` has no column behind it — it asks whether any outbound message
# exists — so the seeded reply below is what makes this number look like one the
# bot has spoken to before.
def unlinked_user
  @unlinked_user ||=
    User.where.not(id: Whatsapp::Account.where.not(user_id: nil).select(:user_id)).first ||
    abort("every user in this DB already has a WhatsApp account — nothing to link the harness to")
end

def account
  @account ||= begin
    record = Whatsapp::Account.create!(
      wa_id: "49#{rand(1_000_000_000..9_999_999_999)}",
      phone: "scenario-harness",
      profile_name: "Scenario Harness",
      user: unlinked_user,
      state: "linked",
      verified_at: Time.current,
      ai_disclosed_at: Time.current,
      terms_accepted_at: Time.current,
      last_inbound_at: Time.current
    )

    Whatsapp::Message.create!(
      whatsapp_account: record,
      direction: "outbound",
      kind: "text",
      body: "Guten Tag.",
      wa_message_id: "wamid.seed.#{SecureRandom.hex(6)}",
      status: "delivered",
      sent_at: 2.weeks.ago,
      created_at: 2.weeks.ago
    )

    record
  end
end

def conversation
  account.conversation
end

# One citizen message through the whole gate chain.
#
# `gap` is what the conversation's clock is wound back to before the message
# lands, which is how the elapsed-gap branches are reached: ProcessMessageService
# reads last_inbound_at exactly once, before overwriting it.
def say(text, gap: nil, kind: "text", raw: {})
  SENT.clear

  conversation.update!(last_inbound_at: gap.present? ? gap.ago : nil)
  account.update!(last_inbound_at: Time.current)

  inbound = Whatsapp::Message.create!(
    whatsapp_account: account,
    direction: "inbound",
    kind: kind,
    body: text,
    wa_message_id: "wamid.in.#{SecureRandom.hex(6)}",
    status: "delivered",
    sent_at: Time.current
  )

  Whatsapp::Inbound::ProcessMessageService.call(whatsapp_message: inbound, raw_message: raw)

  puts "  citizen: #{text}"
  print_replies
rescue StandardError => e
  puts "  !! #{e.class}: #{e.message}"
  puts "     #{e.backtrace.first}"
end

def print_replies
  if SENT.empty?
    puts "  bot:     (nothing sent)"

    return
  end

  SENT.each do |message|
    puts "  bot [#{message[:kind]}]: #{message[:body].to_s.gsub("\n", "\n            ")}"
    puts "      taps: #{message[:options].join(" | ")}" if message[:options].present?
  end
end

# A notification the bot pushed on its own initiative, for the scenario that
# replies to one. Sent through the real template path so it lands in
# whatsapp_messages exactly as the deadline job's would.
def push_notification(text)
  Whatsapp::Message.create!(
    whatsapp_account: account,
    direction: "outbound",
    kind: "template",
    body: text,
    wa_message_id: "wamid.push.#{SecureRandom.hex(6)}",
    status: "delivered",
    sent_at: 1.day.ago,
    created_at: 1.day.ago
  )
end

def reset_conversation!
  conversation.reset_flow!
  conversation.update!(context: {})
end

# --- scenarios ---------------------------------------------------------

SCENARIOS = {
  1 => [
    "Open question about what is possible — the reply must answer it, not return it",
    -> {
      reset_conversation!
      say("Hallo was kann ich heute tun?", gap: 2.minutes)
    }
  ],
  2 => [
    "Specific intent — taken straight there, no detour through the general menu",
    -> {
      reset_conversation!
      say("Hallo, wo kann ich denn mitmachen?", gap: 5.minutes)
    }
  ],
  3 => [
    "Returning after a week — brief re-orientation to what was last worked on",
    -> {
      reset_conversation!
      say("Ich möchte eine Idee einreichen", gap: 8.days)
      say("Und, gibt's was Neues?", gap: 8.days)
    }
  ],
  4 => [
    "Continuing after a minute mid-submission — no renewed greeting, the addition picked up",
    -> {
      reset_conversation!
      # Genuinely mid-submission, which is what the ticket's example is about: at
      # an idle step the same follow-up is a non-sequitur and the menu is a fair
      # answer to it, so the scenario would prove nothing.
      next if !drafting_available?

      conversation.start_flow!(open_phase)
      say("Mehr Fahrradbügel am Bahnhof", gap: 10.minutes)
      say("ja genau, und am Marktplatz auch", gap: 1.minute)
    }
  ],
  5 => [
    "Several details in one message — photo and location must not be asked again",
    -> {
      reset_conversation!

      next if !drafting_available?

      conversation.start_flow!(open_phase)
      say(
        "Ich möchte eine Idee einreichen: mehr Fahrradbügel am Bahnhof. " \
        "Ein Foto habe ich nicht.",
        gap: 3.minutes
      )
      puts "  -- settled slots: #{conversation.settled_slots.inspect}"
      puts "  -- image question pending: #{conversation.image_question_pending?}"
      puts "  -- location question pending: #{conversation.location_question_pending?}"
    }
  ],
  6 => [
    "Replying to a notification the bot sent yesterday",
    -> {
      reset_conversation!
      # Names a real projekt, because that is what the reply has to resolve. A
      # notification with no projekt in it leaves nothing to pick up, so the bot
      # can only guess and the scenario cannot be read either way.
      push_notification(
        "Bei *#{Whatsapp::ProjektLink.title(open_phase.projekt)}* endet bald die Frist."
      )
      say("was war das nochmal?", gap: 1.day)
    }
  ],
  7 => [
    "Voice message — answered on content, without remarking on the medium",
    -> {
      reset_conversation!
      say("Mehr Bänke am Rummelgang wären gut", gap: 4.minutes, kind: "audio")
    }
  ],
  8 => [
    "Question outside participation — refused in its own words, with what is possible instead",
    -> {
      reset_conversation!
      say("Wann hat denn das Bürgeramt auf?", gap: 6.minutes)
    }
  ],
  9 => [
    "Same intent, two wordings — the two replies must not read alike",
    -> {
      reset_conversation!
      say("wo kann ich mich beteiligen?", gap: 7.minutes)
      reset_conversation!
      say("gibt es was, wo ich mitmachen kann?", gap: 7.minutes)
    }
  ],
  10 => [
    "No repetition — the same question three times in one chat",
    -> {
      reset_conversation!
      say("was läuft grad?", gap: 2.minutes)
      say("und was noch?", gap: 1.minute)
      say("sonst noch was?", gap: 1.minute)
    }
  ]
}.freeze

requested = ARGV.map(&:to_i).presence || SCENARIOS.keys

ActiveRecord::Base.transaction do
  puts "=" * 78
  puts "WhatsApp conversation scenarios — CON-2982"
  puts "AI available: #{Ai::Settings.ai_available?}   provider: #{Ai::Settings.current_llm_provider}"
  puts "Nothing is sent and nothing persists: this whole run is rolled back."
  puts "=" * 78

  requested.each do |number|
    title, scenario = SCENARIOS[number]

    if scenario.blank?
      puts "\n-- #{number}: no such scenario"

      next
    end

    puts "\n-- #{number}. #{title}"
    scenario.call
  end

  puts "\n#{"=" * 78}"
  puts "Composition counters for today:"

  if Rails.cache.is_a?(ActiveSupport::Cache::NullStore)
    puts "  (not recorded — this environment runs the null cache store, and DecisionLog"
    puts "   counts nothing there. nil below means \"not counted\", never \"did not happen\";"
    puts "   read the replies above for whether composition ran.)"
  end

  Whatsapp::AiAssistant::DecisionLog.counts.each do |event, count|
    next if !event.to_s.start_with?("compose_")

    puts "  #{event}: #{count.inspect}"
  end
  puts "=" * 78

  raise ActiveRecord::Rollback
end
