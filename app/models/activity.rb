class Activity < ApplicationRecord
  belongs_to :actionable, -> { with_hidden }, polymorphic: true
  belongs_to :user, -> { with_hidden }, inverse_of: :activities

  VALID_ACTIONS = %w[hide block restore valuate email].freeze

  validates :action, inclusion: { in: ->(*) { VALID_ACTIONS }}

  scope :on_proposals, -> { where(actionable_type: "Proposal") }
  scope :on_debates, -> { where(actionable_type: "Debate") }
  scope :on_users, -> { where(actionable_type: "User") }
  scope :on_comments, -> { where(actionable_type: "Comment") }
  scope :on_budget_investments, -> { where(actionable_type: "Budget::Investment") }
  scope :on_system_emails, -> { where(actionable_type: "ProposalNotification") }
  scope :for_render, -> { includes(user: [:moderator, :administrator]).includes(:actionable) }

  def self.log(user, action, actionable)
    create!(user: user, action: action.to_s, actionable: actionable)
  end

  # One row per id, in a single insert. A newsletter logs one activity per
  # recipient, so a large send would otherwise spend a query per address.
  # insert_all skips validations, callbacks and timestamp assignment, so the
  # action is a caller-controlled literal and both timestamps travel with the
  # row. A nil id is kept: an address with no account is still a delivery.
  def self.log_all(action, actionable, user_ids)
    return if user_ids.blank?

    now = Time.current
    rows = user_ids.map do |user_id|
      {
        user_id: user_id,
        action: action.to_s,
        actionable_type: actionable.class.base_class.name,
        actionable_id: actionable.id,
        created_at: now,
        updated_at: now
      }
    end

    insert_all(rows)
  end

  def self.on(actionable)
    where(actionable: actionable)
  end

  def self.by(user)
    where(user: user)
  end
end
