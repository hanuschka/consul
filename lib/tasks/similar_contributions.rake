namespace :similar_contributions do
  desc "Delete check drafts abandoned before their citizen published them"
  task prune_abandoned_drafts: :environment do
    SimilarContributions::PruneAbandonedDraftsJob.perform_now
  end
end
