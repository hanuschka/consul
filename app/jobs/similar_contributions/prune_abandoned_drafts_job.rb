# Two flows park a draft the citizen may never come back to: a submission on a
# phase with the check enabled, parked before the ranking runs, and the AI
# flow, which writes its generated draft to the database before showing it. Both
# are invisible to everyone but administrators, so nothing else would ever clear
# them. A draft the citizen saved on purpose has neither mark and is kept.
class SimilarContributions::PruneAbandonedDraftsJob < ApplicationJob
  queue_as :default

  RETENTION = 24.hours
  BATCH_SIZE = 500

  def perform
    [::Proposal, ::Budget::Investment].each do |resource_class|
      prune(resource_class)
    end
  end

  private

    def prune(resource_class)
      abandoned(resource_class).in_batches(of: BATCH_SIZE) do |batch|
        count = batch.delete_all

        Rails.logger.info("[SimilarContributions] pruned #{count} abandoned " \
                          "#{resource_class} check drafts")
      end
    end

    def abandoned(resource_class)
      stale = resource_class
        .unscope(where: :draft)
        .where(draft: true, published_at: nil)
        .where(created_at: ...RETENTION.ago)

      stale
        .where.not(similar_contributions_check_status: nil)
        .or(stale.where.not(ai_idea_text: [nil, ""]))
    end
end
