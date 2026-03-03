class ProjektPhase::NewsfeedPhase < ProjektPhase
  def name
    "newsfeed_phase"
  end

  def resources_name
    "newsfeed"
  end

  def admin_nav_bar_items
    %w[naming general_settings]
  end

  def safe_to_destroy?
    true
  end

  private

    def phase_specific_permission_problems(user, location)
      return :organization if user.organization?
    end
end
