class ProjektPhase::VotingPhase < ProjektPhase
  has_many :polls, foreign_key: :projekt_phase_id,
    dependent: :restrict_with_exception, inverse_of: :projekt_phase

  def phase_activated?
    active?
  end

  def name
    "voting_phase"
  end

  def resources_name
    "polls"
  end

  def default_order
    4
  end

  def resource_count
    polls.for_public_render.count
  end

  def admin_nav_bar_items
    %w[duration naming restrictions settings
       poll_questions poll_booth_assignments poll_officer_assignments poll_recounts poll_results
       age_ranges_for_stats]
  end

  def safe_to_destroy?
    polls.empty?
  end

  private

    def phase_specific_permission_problems(user, location)
      return :organization if user.organization?
    end
end
