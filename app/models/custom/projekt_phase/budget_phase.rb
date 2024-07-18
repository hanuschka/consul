class ProjektPhase::BudgetPhase < ProjektPhase
  has_one :budget, foreign_key: :projekt_phase_id,
    dependent: :restrict_with_exception, inverse_of: :projekt_phase

  after_create :create_map_location

  def phase_activated?
    # projekt.budget.present?
    active?
  end

  def name
    "budget_phase"
  end

  def resources_name
    "budget"
  end

  def default_order
    5
  end

  def resource_count
    budget&.investments&.count
  end

  def admin_nav_bar_items
    %w[duration naming restrictions settings map age_ranges_for_stats]
  end

  def safe_to_destroy?
    budget.nil?
  end

  private

    def phase_specific_permission_problems(user, location)
      return :organization if user.organization?
    end
end
