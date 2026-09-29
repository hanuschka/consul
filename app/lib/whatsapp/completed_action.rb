class Whatsapp::CompletedAction
  # Something a turn did before it failed to answer: a comment put on the page, a
  # contribution handed in, a support counted, a projekt followed. Recorded by whatever
  # did it (Whatsapp::Conversation#note_action_completed!), so that a turn which then
  # cannot write its reply is not answered as though nothing had happened — the
  # citizen reading "I can't answer you right now" under their own published comment
  # cannot tell whether it went in.
  #
  # It says the same thing twice, to two readers. `fact` is for the assistant, in
  # English and in the third person like every note in Whatsapp::CompletionNotes, and
  # it is what the retry hands it instead of the request that already went through —
  # replaying that request would act on it a second time, or report that there is
  # nothing left to act on. `line` is for the citizen and is fixed copy, because it is
  # sent precisely when there is no model to write it.
  COPY_KEYS = {
    comment_posted: "whatsapp.bot.assistant_unavailable_after_action.comment_posted",
    contribution_published: "whatsapp.bot.assistant_unavailable_after_action.contribution_published",
    support_registered: "whatsapp.bot.assistant_unavailable_after_action.support_registered",
    support_withdrawn: "whatsapp.bot.assistant_unavailable_after_action.support_withdrawn",
    projekt_followed: "whatsapp.bot.assistant_unavailable_after_action.projekt_followed",
    projekt_unfollowed: "whatsapp.bot.assistant_unavailable_after_action.projekt_unfollowed",
    notification_switched: "whatsapp.bot.assistant_unavailable_after_action.notification_switched",
    account_unlinked: "whatsapp.bot.assistant_unavailable_after_action.account_unlinked"
  }.freeze

  RETRY_HINT_KEY = "whatsapp.bot.assistant_unavailable_after_action.retry_hint".freeze

  attr_reader :kind, :fact, :copy_options

  def self.comment_posted(proposal:, visible:)
    state = visible ? "is on the page" : "is waiting to be looked at before it appears"

    new(
      kind: :comment_posted,
      fact: "their comment#{titled("on ", proposal&.title)} was posted and #{state}"
    )
  end

  def self.contribution_published(resource:, awaiting_review:)
    state = awaiting_review ? "went in and is held for review" : "was published"

    new(
      kind: :contribution_published,
      fact: "their contribution#{titled("", resource&.title)} #{state}"
    )
  end

  def self.support_registered(proposal:)
    new(
      kind: :support_registered,
      fact: "their support#{titled("for ", proposal&.title)} was registered"
    )
  end

  def self.support_withdrawn(proposal:)
    new(
      kind: :support_withdrawn,
      fact: "their support#{titled("for ", proposal&.title)} was taken back"
    )
  end

  # The projekt is named in the citizen's line too, because nothing else tells them:
  # following sends no message of its own, so this line is the whole confirmation.
  def self.projekt_followed(projekt_title:)
    new(
      kind: :projekt_followed,
      fact: "they now follow the projekt#{titled("", projekt_title)}",
      copy_options: { projekt: projekt_title.to_s }
    )
  end

  def self.projekt_unfollowed(projekt_title:)
    new(
      kind: :projekt_unfollowed,
      fact: "they no longer follow the projekt#{titled("", projekt_title)}",
      copy_options: { projekt: projekt_title.to_s }
    )
  end

  def self.notification_switched(notification_type:, enabled:)
    new(
      kind: :notification_switched,
      fact: "their #{notification_type.to_s.tr("_", " ")} notifications were switched " \
            "#{enabled ? "on" : "off"}"
    )
  end

  def self.account_unlinked
    new(kind: :account_unlinked, fact: "their account was unlinked from this number")
  end

  # Read back out of a retry snapshot. A kind this code no longer knows is dropped
  # rather than raised on: the snapshot can be tapped a day after it was written, by
  # which time a deploy may have renamed it, and the citizen is then answered with the
  # plain line instead of a crash.
  def self.from_snapshot(entries)
    Array(entries).filter_map do |entry|
      next if !entry.is_a?(Hash)

      kind = COPY_KEYS.keys.find { |known| known.to_s == entry["kind"].to_s }

      next if kind.blank?

      new(kind: kind, fact: entry["fact"].to_s, copy_options: entry["copy_options"].to_h)
    end
  end

  # Every distinct action the turn completed, then the one sentence saying what is
  # missing and how to get it. All of them rather than the last: a citizen who followed
  # a projekt and switched its notifications on in one message did both.
  def self.unavailable_body(completed_actions)
    [*completed_actions.map(&:line).uniq, ::Whatsapp.copy(RETRY_HINT_KEY)].join(" ")
  end

  def self.titled(prefix, title)
    return "" if title.blank?

    " #{prefix}\"#{title.to_s.squish}\""
  end

  private_class_method :titled

  def initialize(kind:, fact:, copy_options: {})
    @kind = kind
    @fact = fact
    @copy_options = copy_options
  end

  def line
    ::Whatsapp.copy(COPY_KEYS.fetch(kind), **copy_options.symbolize_keys)
  end

  def to_snapshot
    { "kind" => kind.to_s, "fact" => fact, "copy_options" => copy_options.stringify_keys }
  end
end
