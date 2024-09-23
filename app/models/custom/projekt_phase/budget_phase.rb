class ProjektPhase::BudgetPhase < ProjektPhase
  has_one :budget, foreign_key: :projekt_phase_id,
    dependent: :restrict_with_exception, inverse_of: :projekt_phase

  after_create :create_map_location, :create_budget

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

  def selectable_by_users?
    feature?("resource.users_can_create_investment_proposals")
  end

  def selectable_by_admins_only?
    !selectable_by_users?
  end

  def settings_categories
    %w[form_author user_functions]
  end

  def admin_nav_bar_items
    %w[
      duration naming restrictions
      budget_edit budget_investments budget_phases
      form_author user_functions
      map age_ranges_for_stats
      projekt_labels sentiments
    ]
  end

  def safe_to_destroy?
    budget.nil?
  end

  private

    def phase_specific_permission_problems(user, location)
      return :organization if user.organization?
    end

    def create_budget
      return if budget.present?

      budget = Budget.create!(
        projekt_phase: self,
        name: projekt.name,
        currency_symbol: "€",
        slug: "#{projekt.name.to_s.parameterize}-#{Budget.last.id + 1}",
        published: true
      )

      group = Budget::Group.create!(
        budget: budget,
        name: "default_group",
        slug: "default_group"
      )

      Budget::Heading.create!(
        name: "default_heading",
        slug: "default_heading",
        group: group,
        population: 1000,
        price: 1000
      )
    end
end
