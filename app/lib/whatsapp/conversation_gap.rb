module Whatsapp::ConversationGap
  # How long ago the citizen last wrote, as one of four situations rather than a
  # number of seconds. One minute, one hour and one week are three different
  # conversations — carrying on mid-sentence, picking up again, and coming back
  # after a while — and until this existed the bot's reply was identical in all
  # three (CON-2982).
  #
  # Banded rather than handed over as a duration on purpose: what changes is
  # whether the reply greets, continues or re-orients, and a model given "4231
  # seconds" has to decide that for itself, differently each time. The band is
  # also what makes the decision reviewable — three cases to read, not a clock.
  #
  # Read by both prompts that write to a citizen: the assistant's system prompt
  # and the reply composer. The instruction lives here rather than in either of
  # them so the two cannot drift into greeting at different moments.
  FIRST_MESSAGE = :first_message
  MINUTES = :minutes
  HOURS = :hours
  DAYS = :days

  # Half an hour, because a chat that resumes inside it is still the same sitting
  # — the citizen looked something up, took a photo, got interrupted — and
  # greeting them again reads as the bot having forgotten the exchange.
  MINUTES_UNTIL_HOURS = 30.minutes

  # Six hours rather than a calendar day: a morning conversation picked up in the
  # evening is a return, and Conversation::STALE_FLOW_AFTER already treats a
  # night away as long enough to stop resuming a draft silently.
  HOURS_UNTIL_DAYS = 6.hours

  LABELS = {
    FIRST_MESSAGE => "this is their first message in this conversation",
    MINUTES => "minutes since their last message",
    HOURS => "hours since their last message",
    DAYS => "a day or more since their last message"
  }.freeze

  INSTRUCTIONS = {
    FIRST_MESSAGE => "open the conversation, but do not introduce yourself twice",
    MINUTES => "carry straight on. No greeting, no welcome back, no re-introduction — pick up " \
               "what was being said",
    HOURS => "no full greeting, but a short reconnecting clause is right. Name what they were " \
             "last working on if the state below says",
    DAYS => "open with a brief re-orientation: welcome them back and name what they were last " \
            "working on, from the state below, before asking anything"
  }.freeze

  module_function

  # Nil when there is no previous message to measure from, which is a first
  # contact rather than a long absence: treating an unknown gap as DAYS would
  # have the bot welcome a brand-new number back.
  def band(previous_inbound_at, now: Time.current)
    return FIRST_MESSAGE if previous_inbound_at.blank?

    elapsed = now - previous_inbound_at

    return MINUTES if elapsed < MINUTES_UNTIL_HOURS
    return HOURS if elapsed < HOURS_UNTIL_DAYS

    DAYS
  end

  # The whole line a prompt carries, so neither caller assembles it from the two
  # halves and neither can print the band without the instruction that gives it
  # meaning.
  def instruction_line(previous_inbound_at, now: Time.current)
    situation = band(previous_inbound_at, now: now)

    "#{LABELS.fetch(situation)} — #{INSTRUCTIONS.fetch(situation)}"
  end
end
