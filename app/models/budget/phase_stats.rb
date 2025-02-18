class Budget::PhaseStats < Budget::Stats
  attr_reader :budget_phase_name

  def initialize(resource, budget_phase_name)
    @resource = resource
    @budget_phase_name = budget_phase_name
  end

  private

    def participant_ids
      send("participant_ids_#{@budget_phase_name}_phase")
    end

    def participant_ids_accepting_phase
      authors.uniq
    end

    def participant_ids_selecting_phase
      voters.uniq
    end

    def participant_ids_balloting_phase
      (balloters + poll_ballot_voters).uniq
    end

    def stats_cache(key, &block)
      Rails.cache.fetch("budgets_stats/#{budget.id}/#{budget_phase_name}/#{key}/#{version}", &block)
    end
end
