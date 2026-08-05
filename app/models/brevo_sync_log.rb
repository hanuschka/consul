class BrevoSyncLog < ApplicationRecord
  # One row per sync run — the nightly reconcile, an admin pressing "sync now", or a single
  # webhook event. It is the record the client relies on: how many contacts the run saw, which
  # accounts it created or erased, and what went wrong when it failed.
  #
  # `error_message` holds a run-level failure (the API was unreachable, no list configured) while
  # `details` holds one entry per contact that actually changed something or could not be
  # processed. No-ops are counted in `skipped_count` and deliberately left out of `details`, so a
  # nightly run over a settled member list stays a single small row.
  MAX_ERROR_MESSAGE_LENGTH = 10_000
  MAX_DETAILS = 1_000

  ACTIONS = %w[created linked erased failed].freeze

  # The severity each status and action reads as, kept next to the vocabularies they translate so a
  # new action cannot be added without one. Semantic levels, not class names: the view builds the
  # badge out of them.
  BADGE_STYLES = {
    "completed" => "success",
    "failed" => "danger",
    "running" => "info"
  }.freeze

  ACTION_BADGE_STYLES = {
    "created" => "success",
    "erased" => "warning",
    "failed" => "danger",
    "linked" => "info"
  }.freeze

  belongs_to :triggered_by, class_name: "User", optional: true

  enum source: { scheduled: "scheduled", manual: "manual", webhook: "webhook" }, _prefix: true
  enum status: { running: "running", completed: "completed", failed: "failed" }, _prefix: true

  scope :recent, -> { order(created_at: :desc) }

  def self.start!(source:, triggered_by: nil)
    create!(source: source, status: "running", started_at: Time.current, triggered_by: triggered_by)
  end

  # Takes the raw action of a `details` entry, which is a string rather than a record.
  def self.action_badge_style(action)
    ACTION_BADGE_STYLES.fetch(action.to_s, "info")
  end

  def badge_style
    BADGE_STYLES.fetch(status, "info")
  end

  def finish!(status: "completed")
    update!(status: status, finished_at: Time.current)
  end

  def fail!(message)
    update!(status: "failed", finished_at: Time.current,
            error_message: message.to_s.first(MAX_ERROR_MESSAGE_LENGTH))
  end

  # Per-contact outcomes are collected rather than raised: one unusable contact must not abort a
  # run that still has hundreds of good ones to process. A run that recorded a failure is reported
  # as failed at the end so the admin sees it needs attention.
  def record(action:, email: nil, contact_id: nil, message: nil)
    entry = {
      "action" => action.to_s,
      "email" => email.presence,
      "contact_id" => contact_id.presence,
      "message" => message.presence,
      "at" => Time.current.iso8601
    }.compact

    self.details = (details + [entry]).last(MAX_DETAILS)
  end

  def failures
    details.select { |entry| entry["action"] == "failed" }
  end

  def duration_in_seconds
    return if started_at.blank? || finished_at.blank?

    (finished_at - started_at).round
  end

  def changed_anything?
    created_count.positive? || erased_count.positive?
  end
end
