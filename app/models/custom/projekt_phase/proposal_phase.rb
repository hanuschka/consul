class ProjektPhase::ProposalPhase < ProjektPhase
  store_accessor :stats,
    :total_unique_participants_count,
    :visible_proposals_count,
    :proposal_authors_count,
    :unique_supporters_count,
    :total_votes_count,
    :online_votes_count,
    :offline_votes_count,
    :visible_comments_count,
    :total_male_participants,
    :total_female_participants,
    :total_other_gen_participants,
    :male_percentage,
    :female_percentage,
    :other_gen_percentage

  def participants_by_age
    (stats["participants_by_age"] || {}).transform_values(&:with_indifferent_access)
  end

  def participants_by_geozone
    (stats["participants_by_geozone"] || {}).transform_values(&:with_indifferent_access)
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
    false
  end

  def participations
    [].tap do |result|
      result << "gender" if gender?
      result << "age" if age?
      result << "geozone" if geozone?
    end
  end

  def soft_individual_groups
    IndividualGroup.none
  end

  def total_individual_group_value_participants(_value)
    0
  end

  has_many :resources, foreign_key: :projekt_phase_id, class_name: "Proposal",
                       inverse_of: :projekt_phase, dependent: :destroy

  def proposals
    resources
  end

  after_create :copy_map_settings_from_projekt

  def name
    "proposal_phase"
  end

  def resources_name
    "proposals"
  end

  def default_order
    4
  end

  def resource_count
    proposals.base_selection.count
  end

  def selectable_by_users?
    feature?("resource.users_can_create_proposals")
  end

  def selectable_by_admins_only?
    !selectable_by_users?
  end

  def admin_nav_bar_items
    %w[
      duration naming restrictions general_settings form_author user_functions
      proposals comments
      projekt_labels sentiments map
      officing_managers ai_settings user_resource_criteria
    ]
  end

  def embedded_admin_nav_bar_items
    admin_nav_bar_items.excluding(%w[officing_managers])
  end

  def safe_to_destroy?
    proposals.empty?
  end

  def proposal_limit_exceeded?(user)
    max_active_proposals_per_user = Setting["extended_option.proposals.max_active_proposals_per_user"].to_i
    user.proposals.where(retired_at: nil).count >= max_active_proposals_per_user
  end

  private

    def phase_specific_permission_problems(user, location)
      return :organization if user.organization? && location == :votes_component

      :proposals_limit_exceeded if proposal_limit_exceeded?(user)
    end
end
