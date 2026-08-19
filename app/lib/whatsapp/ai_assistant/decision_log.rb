module Whatsapp::AiAssistant::DecisionLog
  # Why a turn went where it did, in one greppable line per decision. Until
  # this existed the assistant's reply was the only evidence of its own
  # reasoning, and it reads plausibly whichever tool was picked — a misroute,
  # a button silently dropped and a rewrite thrown out by its own guardrails
  # all looked like an ordinary answer from the outside.
  #
  # Every line carries the same shape, so `grep '\[Whatsapp\]\[assistant\]'`
  # over a day of logs is a table: event first, then the conversation, then
  # whatever that event has to say for itself.
  TAG = "[Whatsapp][assistant]".freeze

  # Rejections mean nothing without the denominator, so the accepted cases are
  # counted too: two rewrites thrown out is a bug at ten a day and a working
  # guardrail at ten thousand.
  EVENTS = %i[
    tool_called
    option_chosen
    option_dropped
    action_dropped
    actions_unusable
    rewrite_applied
    rewrite_rejected
    rewrite_failed
    flow_parked
    flow_resumed
    fresh_start_routed
    fresh_start_fallback
  ].freeze

  COUNTER_TTL = 40.days

  module_function

  # Never raises and never blocks the reply: this watches the conversation, it
  # is not part of it. An unreachable cache costs the count, not the message.
  def record(event:, conversation: nil, **details)
    Rails.logger.info(line(event: event, conversation: conversation, **details))

    increment(event)

    nil
  rescue StandardError => e
    Rails.logger.info("#{TAG} decision log failed: #{e.class} - #{e.message}")

    nil
  end

  # One day's counts, for reading back from a console or an admin page later.
  # Nil per event rather than zero when nothing was counted: "not recorded" and
  # "recorded none" are different answers, and the cache cannot tell them apart
  # after the TTL.
  def counts(date: Time.zone.today)
    EVENTS.index_with { |event| Rails.cache.read(counter_key(event, date), raw: true)&.to_i }
  end

  def line(event:, conversation:, **details)
    pairs = { event: event, conversation: conversation&.id }
      .merge(details)
      .compact
      .map { |key, value| "#{key}=#{loggable(value)}" }

    "#{TAG} #{pairs.join(" ")}"
  end

  # Squished and cut because the citizen's own words end up here and a chat
  # message is not a log line: what matters is which decision it produced.
  def loggable(value)
    text = value.to_s.squish.truncate(80)

    return text if text.exclude?(" ")

    "\"#{text}\""
  end

  # `increment` on a key that does not exist yet answers differently per store —
  # memcached creates it, the in-memory store returns nil and writes nothing —
  # so the first count of the day is written explicitly. Raw, because a
  # marshalled value cannot be incremented afterwards on memcached.
  #
  # Two processes racing the first count of an event lose one of them. That is
  # the right trade for a number read as a rate: a lock per log line would cost
  # more than the count is worth.
  def increment(event)
    return if Rails.cache.is_a?(ActiveSupport::Cache::NullStore)

    key = counter_key(event, Time.zone.today)

    return if Rails.cache.increment(key, 1, expires_in: COUNTER_TTL).present?

    Rails.cache.write(key, 1, expires_in: COUNTER_TTL, raw: true)
  end

  def counter_key(event, date)
    "whatsapp/assistant/#{date.iso8601}/#{event}"
  end
end
