require_dependency Rails.root.join("app", "models", "comment").to_s

class Comment < ApplicationRecord
  include Search::Generic

  scope :seen, -> { where.not(ignored_flag_at: nil) }
  scope :unseen, -> { where(ignored_flag_at: nil) }

  def elastic_searchable?
    hidden_at.nil?
  end
end
