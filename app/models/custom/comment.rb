require_dependency Rails.root.join("app", "models", "comment").to_s
class Comment < ApplicationRecord
  include Search::Generic

  def elastic_searchable?
    hidden_at.nil?
  end
end
