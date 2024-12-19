class Administrator < ApplicationRecord
  belongs_to :user, touch: true
  has_many :budget_administrators, dependent: :destroy

  delegate :name, :email, :name_and_email, to: :user

  validates :user_id, presence: true, uniqueness: true

  scope :with_user, -> { includes(:user) }

  after_create :sync_user
  after_destroy :sync_user

  def description_or_name
    description.presence || name
  end

  def description_or_name_and_email
    "#{description_or_name} (#{email})"
  end

  def sync_user
    user.sync_user_on_dt
  end
end
