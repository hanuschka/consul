require_dependency Rails.root.join("app", "models", "poll").to_s

class Poll < ApplicationRecord
  include Taggable
  include Search::Generic

  scope :last_week, -> { where("polls.created_at >= ?", 7.days.ago) }

  has_and_belongs_to_many :projekts

  def elastic_searchable?
    published? && hidden_at.nil?
  end
end
