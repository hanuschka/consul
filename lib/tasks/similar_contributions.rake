namespace :similar_contributions do
  desc "Create the pgvector embedding store on a host that has the extension"
  task install_embeddings: :environment do
    connection = ActiveRecord::Base.connection

    case SimilarContributionEmbeddingsInstaller.install(connection)
    when :installed
      puts "Created #{SimilarContributionEmbeddingsInstaller::TABLE_NAME}."
    when :present
      puts "#{SimilarContributionEmbeddingsInstaller::TABLE_NAME} already exists."
    when :unavailable
      major = SimilarContributionEmbeddingsInstaller.server_major_version(connection)
      abort "pgvector is not available on PostgreSQL #{major}. Install the extension first."
    end
  end

  desc "Delete check drafts nobody came back to publish"
  task prune_abandoned_drafts: :environment do
    SimilarContributions::PruneAbandonedDraftsJob.perform_now
  end

  desc "Embed published contributions in phases where the similarity check is on"
  task :backfill_embeddings, [:projekt_phase_id] => :environment do |_task, args|
    unless SimilarContributions::Embed.available?
      abort "pgvector or the AI provider is unavailable on this host -- nothing to backfill."
    end

    phases = SimilarContributions::EnabledPhasesQuery.call
    phases = phases.where(id: args[:projekt_phase_id]) if args[:projekt_phase_id].present?

    embedded = 0

    phases.find_each do |projekt_phase|
      SimilarContributions::BackfillPhaseEmbeddings
        .call(projekt_phase) { |count| embedded += count; print "." }

      puts " #{projekt_phase.class.name}##{projekt_phase.id} #{projekt_phase.title}"
    end

    puts "Embedded #{embedded} contribution(s) whose vector was missing or stale."
  end
end
