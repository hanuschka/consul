class Whatsapp::RecentDialogQuery < ApplicationQuery
  # The tail of one number's chat, both directions, oldest first — the record of
  # what has actually been said on this channel.
  #
  # It exists because the assistant's own stored history is not that record.
  # ChatState keeps the router's turns so a replayed tool call cannot be made
  # twice, and it is written only by RouterService: a whole submission answered
  # by the deterministic flow, and every notification the bot pushed, leave no
  # trace in it at all. A citizen asking "was war das nochmal?" about yesterday's
  # deadline notice was therefore answered from nothing (CON-2982).
  #
  # Read from whatsapp_messages rather than by teaching each sender to append
  # somewhere: every message the bot sends already records a row here, so one
  # reader covers the flow, the assistant, the broadcasts, and anything written
  # later without it having to know this exists.
  #
  # Failed sends are left out. The citizen never saw them, so a reply that refers
  # back to one is talking about a message that does not exist on their phone.
  #
  # `excluding_wa_message_id` is the message being answered right now, and leaving
  # it out is not an optimisation. Inbound::IngestWebhookService persists the row
  # before it enqueues the job that replies to it, so by the time this runs the
  # citizen's current message is already the newest row here — and the prompts
  # present this list as things that have been dealt with and must not be
  # answered again. Included, the one message the bot exists to answer would
  # arrive labelled as answered.
  def initialize(account:, limit:, excluding_wa_message_id: nil)
    @account = account
    @limit = limit
    @excluding_wa_message_id = excluding_wa_message_id
  end

  def call
    return [] if @account.blank?

    scope.reverse
  end

  private

    # Newest-first in SQL to use the index, reversed in Ruby so the caller reads
    # the chat in the order it happened. `limit` before the reverse is the whole
    # point: the tail is what matters and the history of a long-standing number
    # is unbounded.
    def scope
      excluded_current
        .where(whatsapp_account_id: @account.id)
        .where.not(status: "failed")
        .where.not(body: [nil, ""])
        .order(created_at: :desc, id: :desc)
        .limit(@limit)
        .pluck(:direction, :kind, :body, :created_at)
        .map do |direction, kind, body, created_at|
          { direction: direction, kind: kind, body: body, created_at: created_at }
        end
    end

    def excluded_current
      return Whatsapp::Message.all if @excluding_wa_message_id.blank?

      Whatsapp::Message.where.not(wa_message_id: @excluding_wa_message_id)
    end
end
