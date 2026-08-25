class ProjektPhase::StatsRefreshService
  STATS_SERVICES = {
    ProjektPhase::ProposalPhase => ProjektPhase::ProposalPhase::StatsService,
    ProjektPhase::BudgetPhase   => ProjektPhase::BudgetPhase::StatsService,
    ProjektPhase::CommentPhase  => ProjektPhase::CommentPhase::StatsService
  }.freeze

  def call
    ProjektPhase.where(type: STATS_SERVICES.keys.map(&:name))
      .includes(:projekt_phase_evaluation)
      .find_each do |phase|
      service_class = STATS_SERVICES[phase.class]
      next if service_class.blank?
      next if !refreshable?(phase)
      next if !stale?(phase)

      refresh_phase(phase, service_class)
    end
  end

  private

    def refresh_phase(phase, service_class)
      evaluation_row = phase.projekt_phase_evaluation

      if evaluation_row&.completed?
        ProjektEvaluations::GeneratePhaseEvaluation.refresh_regular_stats(evaluation_row)
      else
        service_class.new(phase).call
      end
    end

    def refreshable?(phase)
      case phase
      when ProjektPhase::BudgetPhase
        phase.budget.present?
      else
        true
      end
    end

    def stale?(phase)
      cutoff = phase.stats_refreshed_at
      return true if cutoff.nil?

      case phase
      when ProjektPhase::ProposalPhase
        phase.proposals.where("updated_at > ?", cutoff).exists?
      when ProjektPhase::BudgetPhase
        phase.budget&.investments&.where("updated_at > ?", cutoff)&.exists? || false
      when ProjektPhase::CommentPhase
        phase.comments.where("updated_at > ?", cutoff).exists? ||
          comment_participants_count(phase) != phase.stats["participants_count"].to_i
      end
    end

    def comment_participants_count(phase)
      phase.comments.where(hidden_at: nil).select(:user_id).distinct.count
    end
end
