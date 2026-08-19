class Whatsapp::AiAssistant::DialogDigest
  # Two readings of the same tail of the chat, because two criteria need one
  # query between them (CON-2982):
  #
  #   * #transcript — what has been said on this channel, so a reply can refer
  #     back to it. Covers what the assistant's own stored history cannot: turns
  #     answered by the deterministic submission flow, and notifications the bot
  #     pushed on its own initiative.
  #   * #used_phrasings — the bot's own recent sentences, handed to the composer
  #     as wordings not to reach for again. Nothing tracked this before, so
  #     "within a conversation the bot does not repeat the same phrasing" had no
  #     input at all: PhrasingService picked a variant at random.
  #
  # Deliberately overlapping the replayed router history rather than trying to
  # subtract it. Knowing which rows the stored chat already accounts for would
  # need a synchronisation marker on the conversation, and the marker would lie
  # the moment a flow message landed after the router saved its state. The cost
  # of the overlap is a short block of truncated text; the cost of the marker is
  # a reply that refers back to a message the bot has silently forgotten.
  MAX_MESSAGES = 12

  # Long enough to recognise which message is meant, short enough that twelve of
  # them do not crowd out the prompt they are context for. A projekt card body is
  # several hundred characters of title and URL, and none of it helps here.
  MAX_BODY_LENGTH = 160

  # Only the bot's prose is worth avoiding twice. Interactive bodies are counted
  # too — a menu's sentence is exactly the one that reads as a form when it comes
  # back unchanged — but templates are not: their wording is Meta-approved and
  # unchangeable, so listing them would ask the composer to avoid something it
  # cannot influence.
  PHRASING_KINDS = %w[text interactive].freeze

  MAX_USED_PHRASINGS = 6

  # `excluding_wa_message_id` is the message being answered, which must not appear
  # in a list both prompts introduce as already dealt with — see
  # Whatsapp::RecentDialogQuery, where the ordering that makes it necessary is
  # documented. Built once per turn and memoized on the turn's MessageContext, so
  # the two prompts that read it share one query.
  def initialize(account:, excluding_wa_message_id: nil)
    @account = account
    @excluding_wa_message_id = excluding_wa_message_id
  end

  # Nil rather than an empty string when there is nothing to show, so a prompt
  # can leave the whole section out instead of printing an empty heading.
  def transcript
    return if messages.blank?

    messages.map { |message| line_for(message) }.join("\n")
  end

  def used_phrasings
    outbound
      .select { |message| PHRASING_KINDS.include?(message[:kind]) }
      .last(MAX_USED_PHRASINGS)
      .map { |message| truncated(message[:body]) }
  end

  private

    def messages
      @messages ||= ::Whatsapp::RecentDialogQuery.call(
        account: @account,
        limit: MAX_MESSAGES,
        excluding_wa_message_id: @excluding_wa_message_id
      )
    end

    def outbound
      messages.select { |message| message[:direction] == "outbound" }
    end

    # A notification is marked as one. Without that the model reads a broadcast
    # as something it said in conversation, and a citizen asking what it was
    # about gets an answer that assumes they were mid-chat at the time.
    def line_for(message)
      "- #{[dated(message), speaker_for(message)].compact.join(", ")}: " \
        "#{truncated(message[:body])}"
    end

    def speaker_for(message)
      return "citizen" if message[:direction] == "inbound"
      return "bot (notification pushed to them)" if message[:kind] == "template"

      "bot"
    end

    # Only when it is not from today. DatePhrase works in whole days, so every
    # message of one sitting would otherwise carry the same "heute" — twelve
    # lines of noise saying nothing the order does not already say. What matters
    # is which messages belong to an earlier day, and that it is spelled out
    # rather than in digits, which WhatsApp renders as a callable phone number.
    def dated(message)
      created_at = message[:created_at]

      return if created_at.blank?
      return if created_at.to_date == Time.zone.today

      ::Whatsapp::DatePhrase.relative(created_at)
    end

    def truncated(body)
      body.to_s.squish.truncate(MAX_BODY_LENGTH)
    end
end
