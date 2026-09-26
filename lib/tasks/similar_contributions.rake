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

  desc "Group existing contributions into a duplicate set so the admin list and the badge popup " \
       "have something to show in development. Arguments: [projekt_id,size], both optional"
  task :seed_dev_groups, [:projekt_id, :size] => :environment do |_task, args|
    if !Rails.env.development?
      abort "Development only -- this task writes duplicate sets."
    end

    projekt_ids =
      if args[:projekt_id].present?
        [args[:projekt_id].to_i]
      else
        Projekt.ids
      end

    size = (args[:size] || 3).to_i

    # The paths come off the real view helper rather than being rebuilt here, so
    # a change to where a match links stays in one place.
    helpers = ApplicationController.new
      .tap { |controller| controller.request = ActionDispatch::TestRequest.create }
      .view_context

    report = lambda do |label, group|
      if group.nil?
        puts "#{label}: nothing was grouped."
        next
      end

      puts "#{label}: group ##{group.id} in projekt ##{group.projekt_id}"

      group.contributions.each do |contribution|
        projekt_phase = SimilarContributions::Scopes.projekt_phase_of(contribution)
        state = SimilarContributions::Scopes.enabled_for?(projekt_phase) ? "check on " : "CHECK OFF"
        path = helpers.similar_contributions_backend_path_for(contribution)

        puts "  #{state}  #{path}"
      end
    end

    build = lambda do |resources|
      matches = resources.drop(1).map do |resource|
        SimilarContributions::Ranking::Match.new(
          resource: resource,
          relevance: 95,
          reason: "Seeded duplicate set for development."
        )
      end

      SimilarContributions::RecordGroup.call(resources.first, matches)
    end

    proposal_rows = Proposal
      .where.not(
        id: SimilarContributionMembership.where(contribution_type: "Proposal").select(:contribution_id)
      )
      .where.not(projekt_phase_id: nil)
      .joins(:projekt_phase)
      .where(projekt_phases: { projekt_id: projekt_ids })
      .order(:id)
      .pluck("projekt_phases.projekt_id", :projekt_phase_id, :id)

    cross_phase_projekt = proposal_rows
      .group_by(&:first)
      .transform_values { |rows| rows.group_by { |row| row[1] } }
      .find { |_, rows_by_phase| rows_by_phase.size > 1 }

    if cross_phase_projekt.nil?
      puts "No projekt has ungrouped proposals in more than one phase -- no proposal set built."
    else
      picked_ids = cross_phase_projekt.last.values.first(size).map { |rows| rows.first.last }
      proposals = Proposal.where(id: picked_ids).to_a

      report.call("Proposals across #{picked_ids.size} phases", build.call(proposals))
    end

    investment_rows = Budget::Investment
      .where.not(
        id: SimilarContributionMembership
          .where(contribution_type: "Budget::Investment")
          .select(:contribution_id)
      )
      .joins(budget: :projekt_phase)
      .where(projekt_phases: { projekt_id: projekt_ids })
      .order(:id)
      .pluck("projekt_phases.projekt_id", :id)

    investment_projekt = investment_rows
      .group_by(&:first)
      .find { |_, rows| rows.size > 1 }

    if investment_projekt.nil?
      puts "No projekt has two or more ungrouped budget investments -- no investment set built."
    else
      picked_ids = investment_projekt.last.first(size).map(&:last)
      investments = Budget::Investment.where(id: picked_ids).to_a

      report.call("Budget investments", build.call(investments))
    end
  end
end
