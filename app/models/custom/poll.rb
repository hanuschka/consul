require_dependency Rails.root.join("app", "models", "poll").to_s

class Poll < ApplicationRecord
  include Taggable

  scope :last_week, -> { where("polls.created_at >= ?", 7.days.ago) }

  belongs_to :projekt, optional: true
  has_many :geozone_affiliations, through: :projekt

  def answerable_by?(user)
    user &&
      !user.organization? &&
      user.level_three_verified? &&
      current? &&
      (!geozone_restricted || geozone_ids.include?(user.geozone_id) || user.level_three_verified?)
  end

  def comments_allowed?(user)
    answerable_by?(user)
  end
end
