class ProjektPhase::StatsRefreshService
  STATS_SERVICES = {
    ProjektPhase::ProposalPhase => ProjektPhase::ProposalPhase::StatsService,
    ProjektPhase::BudgetPhase   => ProjektPhase::BudgetPhase::StatsService,
    ProjektPhase::CommentPhase  => ProjektPhase::CommentPhase::StatsService
  }.freeze

  def call
    ProjektPhase.where(type: STATS_SERVICES.keys.map(&:name)).find_each do |phase|
      service_class = STATS_SERVICES[phase.class]
      next unless service_class
      next unless refreshable?(phase)
      next unless stale?(phase)

      service_class.new(phase).call
    end
  end

  private

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
        phase.comments.where("updated_at > ?", cutoff).exists?
      end
    end
end
