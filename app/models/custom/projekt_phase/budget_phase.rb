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
    :finished_winners_count,
    :total_male_participants,
    :total_female_participants,
    :total_other_gen_participants,
    :male_percentage,
    :female_percentage,
    :other_gen_percentage,
    :individual_group_value_counts

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
    total_male_participants.to_i > 0 ||
      total_female_participants.to_i > 0 ||
      total_other_gen_participants.to_i > 0
  end

  def age?
    participants_by_age.values.any? { |v| v[:count].to_i > 0 }
  end

  def geozone?
    participants_by_geozone.values.any? { |v| v[:count].to_i > 0 }
  end

  def individual_group?
    group_value_counts.values.any? { |count| count.to_i > 0 }
  end

  def participations
    [].tap do |result|
      result << "gender" if gender?
      result << "age" if age?
      result << "geozone" if geozone?
    end
  end

  def soft_individual_groups
    @soft_individual_groups ||= begin
      value_ids = group_value_counts.select { |_, count| count.to_i > 0 }.keys

      if value_ids.blank?
        IndividualGroup.none
      else
        IndividualGroup
          .joins(:individual_group_values)
          .where(kind: "soft", individual_group_values: { id: value_ids })
          .distinct
          .preload(:individual_group_values)
      end
    end
  end

  def total_individual_group_value_participants(individual_group_value)
    group_value_counts.fetch(individual_group_value.id.to_s, 0).to_i
  end

  def participants_by_age
    (stats["participants_by_age"] || {}).transform_values(&:with_indifferent_access)
  end

  def participants_by_geozone
    (stats["participants_by_geozone"] || {}).transform_values(&:with_indifferent_access)
  end

  def segment_stats(segment_key)
    ProjektPhase::BudgetPhase::SegmentStats.new(self, segment_key)
  end

  has_one :budget, foreign_key: :projekt_phase_id,
    dependent: :destroy, inverse_of: :projekt_phase

  after_create :copy_map_settings_from_projekt, :create_budget

  def name
    "budget_phase"
  end

  def sidebar_cta_kind
    return :new_button if budget&.accepting?
    return :budget_vote if budget&.selecting?
    return :budget_ballot if budget&.balloting?
  end

  def resources_name
    "budget"
  end

  def default_order
    5
  end

  def investment_orders
    orders = Budget::Investment::DEFAULT_ORDERS.dup
    orders.delete("comments_count") if feature?("resource.hide_comments_count_order")
    orders
  end

  def resource_count
    budget&.investments&.count
  end

  def selectable_by_users?
    feature?("resource.users_can_create_investment_proposals")
  end

  def ai_flow_feature_key
    "resource.create_investment_with_ai"
  end

  def selectable_by_admins_only?
    !selectable_by_users?
  end

  def customizable_email_template_groups
    [
      {
        key: "submission",
        templates: [
          { mailer_class: "Mailer", mailer_action: "budget_investment_created", recipient_type: "author" },
          { mailer_class: "NotificationServiceMailer", mailer_action: "new_budget_investment", recipient_type: "subscribers" }
        ]
      },
      {
        key: "feasibility",
        templates: [
          { mailer_class: "Mailer", mailer_action: "budget_investment_feasible", recipient_type: "author" },
          { mailer_class: "Mailer", mailer_action: "budget_investment_unfeasible", recipient_type: "author" }
        ]
      },
      {
        key: "preselection",
        templates: [
          { mailer_class: "Mailer", mailer_action: "budget_investment_preselected", recipient_type: "author" },
          { mailer_class: "Mailer", mailer_action: "budget_investment_not_preselected", recipient_type: "author" }
        ]
      },
      {
        key: "selection",
        templates: [
          { mailer_class: "Mailer", mailer_action: "budget_investment_selected", recipient_type: "author" },
          { mailer_class: "Mailer", mailer_action: "budget_investment_unselected", recipient_type: "author" }
        ]
      }
    ]
  end

  def customizable_email_templates
    customizable_email_template_groups.flat_map do |group|
      group[:templates].map { |t| [t[:mailer_class], t[:mailer_action]] }
    end
  end

  def admin_nav_bar_items
    items = %w[
      budget_phases
      naming restrictions
      budget_edit budget_investments comments
      general_settings form_author user_functions
      map age_ranges_for_stats
      projekt_labels sentiments
      officing_managers
      email_templates
      ai_settings ai_user_flow
    ]

    return items if !::Whatsapp.enabled?

    items + %w[whatsapp]
  end


  def safe_to_destroy?
    budget.nil?
  end

  def after_hide
    budget&.investments&.each(&:hide)
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

  def supports_limit_applies?
    max_supports_per_user.positive?
  end

  private

    def group_value_counts
      individual_group_value_counts || {}
    end

    def phase_specific_permission_problems(user, location)
      return :organization if user.organization?

      if location.in?(ProjektPhase::SUBMISSION_LOCATIONS) && submissions_limit_exceeded?(user)
        :submissions_limit_exceeded
      elsif location == :votes_component && supports_limit_exceeded?(user)
        :supports_limit_exceeded
      end
    end

    def submissions_limit_exceeded?(user)
      return false if max_submissions_per_user.zero?

      budget.investments.where(author: user).count >= max_submissions_per_user
    end

    def supports_limit_exceeded?(user)
      return false unless supports_limit_applies?

      supports_count_for(user) >= max_supports_per_user
    end

    # Conditional supports count too, otherwise an unverified user could cast any number of
    # them and have them all confirmed at once.
    def supports_count_for(user)
      ActsAsVotable::Vote.where(voter: user, vote_flag: true, votable_type: "Budget::Investment",
                                votable_id: budget.investments.select(:id)).count
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
        budget:,
        name: "default_group",
        slug: "default_group"
      )

      Budget::Heading.create!(
        name: "default_heading",
        slug: "default_heading",
        group:,
        population: 1000,
        price: 1000
      )
    end
end
