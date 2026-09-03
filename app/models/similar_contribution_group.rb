class SimilarContributionGroup < ApplicationRecord
  belongs_to :projekt

  has_many :similar_contribution_memberships, dependent: :destroy

  def contributions
    similar_contribution_memberships.map(&:contribution).compact
  end
end
