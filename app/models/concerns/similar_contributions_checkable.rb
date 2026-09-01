module SimilarContributionsCheckable
  extend ActiveSupport::Concern

  included do
    enum similar_contributions_check_status: {
      pending: "pending",
      processing: "processing",
      completed: "completed",
      failed: "failed"
    }, _prefix: :similar_contributions_check
  end

  def similar_contributions_check_finished?
    similar_contributions_check_completed? || similar_contributions_check_failed?
  end

  def stored_similar_contributions_matches
    Array(similar_contributions_matches)
  end
end
