class SimilarContributionExclusion < ApplicationRecord
  belongs_to :contribution, polymorphic: true
  belongs_to :excluded_contribution, polymorphic: true
  belongs_to :excluded_by, class_name: "User", optional: true

  # The decision is mutual: an admin who says these two are not duplicates has
  # said it for both directions, so it is written and read as a pair.
  def self.between?(contribution, other)
    where(contribution: contribution, excluded_contribution: other)
      .or(where(contribution: other, excluded_contribution: contribution))
      .exists?
  end

  def self.record(contribution, other, admin)
    create!(contribution: contribution, excluded_contribution: other, excluded_by: admin)
  end
end
