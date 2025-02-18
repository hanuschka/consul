class ProjektPhase::BudgetPhase < ProjektPhase
  has_one :budget, foreign_key: :projekt_phase_id,
    dependent: :restrict_with_exception, inverse_of: :projekt_phase

  after_create :copy_map_settings_from_projekt, :create_budget

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
      budget_phases
      naming restrictions
      budget_edit budget_investments
      form_author user_functions
      map age_ranges_for_stats
      projekt_labels sentiments
      officing_managers officing_manager_audits
    ]
  end

  def embedded_admin_nav_bar_items
    admin_nav_bar_items.excluding(%w[ officing_managers officing_manager_audits])
  end

  def safe_to_destroy?
    budget.nil?
  end

  def authors_of_feasible_ids
    budget.investments.feasible.pluck(:author_id).uniq
  end

  def authors_of_unfeasible_ids
    budget.investments.unfeasible.pluck(:author_id).uniq
  end

  def authors_of_selected_ids
    budget.investments.selected.pluck(:author_id).uniq
  end

  def authors_of_not_winners_ids
    budget.investments.selected.compatible.where(winner: true).pluck(:author_id).uniq
  end

  def authors_of_winners_ids
    budget.investments.winners.pluck(:author_id).uniq
  end

  private

    def phase_specific_permission_problems(user, location)
      return :organization if user.organization?
    end

    def create_budget
      return if budget.present?

      name_extension = projekt.budgets.count > 0 ? projekt.budgets.count + 1 : nil

      budget = Budget.create!(
        projekt_phase: self,
        name: [projekt.name, name_extension].compact.join(" "),
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
