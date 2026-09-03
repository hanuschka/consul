class SimilarContributionMembership < ApplicationRecord
  belongs_to :similar_contribution_group
  belongs_to :contribution, polymorphic: true
end
