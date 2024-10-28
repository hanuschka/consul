require_dependency Rails.root.join("app", "models", "votation_type").to_s

class VotationType < ApplicationRecord
  translates :min_rating_scale_label, :max_rating_scale_label, touch: true
  include Globalizable

  enum vote_type: %w[unique multiple multiple_with_weight rating_scale]

  def self.allowing_multiple_answers
    %w[multiple multiple_with_weight]
  end
end
