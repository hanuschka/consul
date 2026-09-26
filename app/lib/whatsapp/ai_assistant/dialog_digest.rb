class Whatsapp::AiAssistant::DialogDigest
  # What has been said on this channel, so a reply can refer back to it. It covers
  # what the assistant's own stored history cannot: the notifications the bot pushed
  # on its own initiative, and every turn from before this conversation had a stored
  # history at all.
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

  # Where one subject ends and the next begins, written into the transcript rather
  # than left for the model to infer. Without it every line reads as equally
  # current, and an answer took its subject from a projekt the citizen had left
  # two subjects earlier (CON-3091).
  #
  # Drawn rather than worded: the sentence saying what it means belongs to the
  # prompt that introduces this list, which is the only thing that knows how the
  # list is framed. This marks the place.
  SUBJECT_BOUNDARY_LINE = "- ─────── the citizen moved on to a different subject here ───────".freeze

  # `excluding_wa_message_id` is the message being answered, which must not appear
  # in a list the prompt introduces as already dealt with — see
  # Whatsapp::RecentDialogQuery, where the ordering that makes it necessary is
  # documented.
  #
  # `subject_changed_at` is Whatsapp::Conversation#subject_changed_at, and nil is a
  # conversation that has never changed subject — the whole window is one subject
  # and no boundary is drawn.
  def initialize(account:, excluding_wa_message_id: nil, subject_changed_at: nil)
    @account = account
    @excluding_wa_message_id = excluding_wa_message_id
    @subject_changed_at = subject_changed_at
  end

  # Nil rather than an empty string when there is nothing to show, so a prompt
  # can leave the whole section out instead of printing an empty heading.
  def transcript
    return if messages.blank?

    transcript_lines.join("\n")
  end

  # Whether the transcript actually carries a boundary, so the prompt can explain
  # one only when there is one to explain. A rule about a line the model cannot
  # see is a rule it has to invent a referent for.
  def subject_boundary?
    messages.present? && !boundary_position.zero?
  end

  private

    def transcript_lines
      lines = messages.map { |message| line_for(message) }

      return lines if boundary_position.zero?

      lines.insert(boundary_position, SUBJECT_BOUNDARY_LINE)
    end

    # The index the boundary line takes in the transcript, which is where the
    # first message belonging to the current subject sits. Zero means every
    # message is already part of it and there is nothing above to close off —
    # a line there would sit at the top with nothing before it.
    #
    # Past the end is the other useful case rather than a degenerate one: the
    # subject changed after the newest message in the window, so the whole
    # transcript is closed and the boundary belongs at the bottom. Array#insert
    # appends at exactly that index.
    #
    # Zero is truthy, so memoising with ||= is safe here.
    def boundary_position
      @boundary_position ||= first_current_message_index
    end

    def first_current_message_index
      return 0 if @subject_changed_at.blank?

      messages.index { |message| current_subject?(message) } || messages.length
    end

    # A message with no timestamp cannot be placed on either side of the change,
    # and counting it as current is the harmless direction: the boundary moves
    # earlier, so nothing that belongs to a closed subject is presented as open.
    def current_subject?(message)
      created_at = message[:created_at]

      return true if created_at.blank?

      created_at >= @subject_changed_at
    end

    def messages
      @messages ||= ::Whatsapp::RecentDialogQuery.call(
        account: @account,
        limit: MAX_MESSAGES,
        excluding_wa_message_id: @excluding_wa_message_id
      )
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
