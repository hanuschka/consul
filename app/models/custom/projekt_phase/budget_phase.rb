class ProjektPhase::BudgetPhase < ProjektPhase
  store_accessor :stats,
    :accepting_visible_proposals_count,
    :accepting_proposal_authors_count,
    :accepting_comments_count,
    :accepting_reported_proposals_count,
    :reviewing_pending_proposals_count,
    :reviewing_approved_proposals_count,
    :reviewing_rejected_proposals_count,
    :selecting_unique_supporters_count,
    :selecting_total_votes_count,
    :selecting_online_votes_count,
    :selecting_offline_votes_count,
    :publishing_prices_selected_proposals_count,
    :publishing_prices_not_selected_proposals_count,
    :balloting_unique_voters_count,
    :balloting_total_votes_count,
    :balloting_weighted_votes_total,
    :balloting_weighted_votes_online,
    :balloting_weighted_votes_offline,
    :finished_winners_count

  def has_accepting_stats?
    accepting_visible_proposals_count.to_i > 0 || accepting_proposal_authors_count.to_i > 0
  end

  def has_reviewing_stats?
    reviewing_approved_proposals_count.to_i > 0 ||
      reviewing_rejected_proposals_count.to_i > 0 ||
      reviewing_pending_proposals_count.to_i > 0
  end

  def has_selecting_stats?
    selecting_total_votes_count.to_i > 0
  end

  def has_publishing_prices_stats?
    publishing_prices_selected_proposals_count.to_i > 0 ||
      publishing_prices_not_selected_proposals_count.to_i > 0
  end

  def has_balloting_stats?
    balloting_total_votes_count.to_i > 0
  end

  def has_finished_stats?
    finished_winners_count.to_i > 0
  end

  def gender?
    false
  end

  def age?
    false
  end

  def geozone?
    false
  end

  def individual_group?
    false
  end

  def participations
    []
  end

  def soft_individual_groups
    IndividualGroup.none
  end

  def total_individual_group_value_participants(_value)
    0
  end

  def participants_by_age
    {}
  end

  def participants_by_geozone
    {}
  end

  has_one :budget, foreign_key: :projekt_phase_id,
    dependent: :destroy, inverse_of: :projekt_phase

  after_create :copy_map_settings_from_projekt, :create_budget

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

  def admin_nav_bar_items
    %w[
      budget_phases
      naming restrictions
      budget_edit budget_investments
      general_settings form_author user_functions
      map age_ranges_for_stats
      projekt_labels sentiments
      officing_managers
      ai_settings
    ]
  end

  def embedded_admin_nav_bar_items
    admin_nav_bar_items.excluding(%w[ officing_managers])
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
        slug: "#{projekt.name.to_s.parameterize}-#{(Budget.order(:id).last&.id || 0) + 1}",
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
