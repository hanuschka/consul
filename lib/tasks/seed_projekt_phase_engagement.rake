namespace :projekt_phase do
  desc "Seed projekt phase resources with votes and user ages. Options: projekt_id=123, phase_id=484, update_ages=true/false, vote_probability=0.7"
  task seed_engagement: :environment do
    puts "Starting to seed projekt phase engagement..."

    projekt_id = ENV["projekt_id"]
    phase_id = ENV["phase_id"]
    update_ages = ENV["update_ages"].nil? || ENV["update_ages"] == "true"
    vote_probability = (ENV["vote_probability"] || "0.7").to_f

    puts "Options:"
    puts "  - projekt_id: #{projekt_id || 'all'}"
    puts "  - phase_id: #{phase_id || 'all'}"
    puts "  - update_ages: #{update_ages}"
    puts "  - vote_probability: #{vote_probability}"
    puts ""

    excluded_user_ids =
      User.administrators.ids +
      User.projekt_managers.ids

    users = User.where.not(id: excluded_user_ids).where(hidden_at: nil)

    if users.empty?
      puts "No eligible users found."
      exit
    end

    puts "Found #{users.count} eligible users."

    if update_ages
      puts "Setting random ages for users..."

      users.find_each do |user|
        next if user.date_of_birth.present?

        age = rand(16..70)
        birth_year = age.years.ago.year
        date_of_birth = Date.new(birth_year, rand(1..12), rand(1..28))

        user.update_column(:date_of_birth, date_of_birth)
      end

      puts "Ages updated successfully."
    else
      puts "Skipping age updates."
    end

    if phase_id.present?
      begin
        phase = ProjektPhase.find(phase_id)
        if phase.is_a?(ProjektPhase::ProposalPhase)
          proposal_phases = [phase]
          budget_phases = []
        elsif phase.is_a?(ProjektPhase::BudgetPhase)
          proposal_phases = []
          budget_phases = [phase]
        else
          puts "Error: Phase #{phase_id} is not a ProposalPhase or BudgetPhase (type: #{phase.type})"
          exit
        end
        puts "Processing single phase: #{phase.projekt.name} - #{phase.name} (ID: #{phase_id})"
      rescue ActiveRecord::RecordNotFound
        puts "Error: Phase with ID #{phase_id} not found."
        exit
      end
    elsif projekt_id.present?
      begin
        projekt = Projekt.find(projekt_id)
        proposal_phases = projekt.projekt_phases.where(type: "ProjektPhase::ProposalPhase")
        budget_phases = projekt.projekt_phases.where(type: "ProjektPhase::BudgetPhase")
        puts "Processing phases for projekt: #{projekt.name}"
      rescue ActiveRecord::RecordNotFound
        puts "Error: Projekt with ID #{projekt_id} not found."
        exit
      end
    else
      proposal_phases = ProjektPhase::ProposalPhase.all
      budget_phases = ProjektPhase::BudgetPhase.all
      puts "Processing all projekt phases..."
    end

    puts "\nProcessing #{proposal_phases.count} proposal phases..."

    proposal_phases.each do |phase|
      next if phase.proposals.empty?

      puts "\n  Processing phase: #{phase.projekt.name} - #{phase.name}"

      phase.proposals.published.each do |proposal|
        puts "    - Proposal: #{proposal.title}"

        sample_size = [users.count / 3, 10].max
        selected_users = users.sample(sample_size)

        votes_added = 0

        selected_users.each do |user|
          if rand < vote_probability
            existing_vote = proposal.votes_for.where(voter_id: user.id).first
            next if existing_vote.present?

            vote_value = rand < 0.8 ? "yes" : "no"
            proposal.vote_by(voter: user, vote: vote_value)
            votes_added += 1
          end
        end

        puts "      Added #{votes_added} votes"
      end
    end

    puts "\nProcessing #{budget_phases.count} budget phases..."

    budget_phases.each do |phase|
      next unless phase.budget
      next if phase.budget.investments.empty?

      puts "\n  Processing phase: #{phase.projekt.name} - #{phase.name}"

      phase.budget.investments.each do |investment|
        puts "    - Investment: #{investment.title}"

        sample_size = [users.count / 3, 10].max
        selected_users = users.sample(sample_size)

        votes_added = 0

        selected_users.each do |user|
          if rand < vote_probability
            existing_vote = investment.votes_for.where(voter_id: user.id).first
            next if existing_vote.present?

            vote_value = rand < 0.8 ? "yes" : "no"
            investment.vote_by(voter: user, vote: vote_value)
            votes_added += 1
          end
        end

        puts "      Added #{votes_added} votes"
      end
    end

    puts "\n✓ Projekt phase engagement seeding completed!"
  end
end
