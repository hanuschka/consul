# Every submission on a phase with the check enabled parks a draft before the
# ranking runs, and a citizen who closes the tab never comes back to publish it.
# Those rows are invisible to everyone but administrators, so nothing else would
# ever clear them.
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
      resource_class
        .unscope(where: :draft)
        .where(draft: true, published_at: nil)
        .where.not(similar_contributions_check_status: nil)
        .where(created_at: ...RETENTION.ago)
    end
end
