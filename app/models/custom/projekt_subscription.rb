class ProjektSubscription < ApplicationRecord
  belongs_to :projekt
  belongs_to :user

  validates :user, :projekt, presence: true
  validates :user_id, uniqueness: { scope: :projekt_id }

  scope :active, -> { where(active: true) }
  scope :active_for_user, ->(user) {
    active
      .where(user_id: user.id)
      .joins(:projekt)
      .includes(projekt: { page: :translations })
      .order(created_at: :desc)
  }

  def self.follow!(user:, projekt:)
    write!(user: user, projekt: projekt, active: true)
    RecipientGroups::EnsureProjektSubscribersGroup.call(projekt)
  end

  def self.unfollow!(user:, projekt:)
    write!(user: user, projekt: projekt, active: false)
  end

  def self.following?(user:, projekt:)
    return false if user.blank? || projekt.blank?

    active.exists?(user_id: user.id, projekt_id: projekt.id)
  end

  def self.write!(user:, projekt:, active:)
    upsert(
      { user_id: user.id, projekt_id: projekt.id, active: active },
      unique_by: [:user_id, :projekt_id]
    )
  end

  private_class_method :write!
end
