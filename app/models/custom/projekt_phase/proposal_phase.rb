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

  def sidebar_cta_kind
    :new_button
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

  def customizable_email_templates
    [
      ["Mailer", "proposal_created"],
      ["NotificationServiceMailer", "new_proposal"]
    ]
  end

  def admin_nav_bar_items
    items = %w[
      duration naming restrictions general_settings form_author user_functions
      proposals comments
      projekt_labels sentiments map
      officing_managers email_templates ai_settings ai_user_flow
    ]

    return items if !::Whatsapp.enabled?

    items + %w[whatsapp]
  end


  def safe_to_destroy?
    proposals.empty?
  end

  def after_hide
    proposals.each(&:hide)
  end

  # A "maximum number of supports" rule does not map onto agree/disagree voting: a dislike is not
  # a support and is not counted, yet the gate behind the limit blocks every vote once it is
  # reached - and that widget has no withdraw button, so the user would be frozen out of voting
  # entirely with no way back under the limit. Phases using it are exempt, which means a limit
  # configured on an up/down phase silently does nothing (as on guest phases).
  def supports_limit_applies?
    max_supports_per_user.positive? && !feature?("resource.enable_up_and_down_voting")
  end

  private

    def phase_specific_permission_problems(user, location)
      return :organization if user.organization? && location == :votes_component

      if location == :new_button_component && submissions_limit_exceeded?(user)
        :submissions_limit_exceeded
      elsif location == :votes_component && supports_limit_exceeded?(user)
        :supports_limit_exceeded
      end
    end

    def submissions_limit_exceeded?(user)
      return false if max_submissions_per_user.zero?

      proposals.where(author: user).count >= max_submissions_per_user
    end

    def supports_limit_exceeded?(user)
      return false unless supports_limit_applies?

      supports_count_for(user) >= max_supports_per_user
    end

    # Conditional supports count too, otherwise an unverified user could cast any number of
    # them and have them all confirmed at once on verification.
    def supports_count_for(user)
      ActsAsVotable::Vote.where(voter: user, vote_flag: true,
                                votable_type: "Proposal", votable_id: proposals.select(:id)).count
    end
end
