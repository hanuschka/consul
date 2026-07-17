class ProjektPhase::CommentPhase::StatsService
  def initialize(projekt_phase)
    @projekt_phase = projekt_phase
  end

  def stale?
    @projekt_phase.stats.empty?
  end

  def call
    demographics = ProjektPhase::DemographicsCalculator.new(participant_ids)

    @projekt_phase.update!(
      stats: {
        participants_by_age: demographics.age_data,
        participants_by_geozone: demographics.geozone_data,
        individual_group_value_counts: demographics.individual_group_value_counts,
        **demographics.gender_data
      },
      stats_refreshed_at: Time.current
    )
  end

  private

    def comments
      @comments ||= @projekt_phase.comments.where(hidden_at: nil)
    end

    def participant_ids
      @participant_ids ||= comments.select(:user_id).distinct.pluck(:user_id).compact
    end
end
