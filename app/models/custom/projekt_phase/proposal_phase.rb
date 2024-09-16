class ProjektPhase::ProposalPhase < ProjektPhase
  has_many :proposals, foreign_key: :projekt_phase_id, dependent: :restrict_with_exception,
    inverse_of: :projekt_phase

  has_many :base_selection_proposals, -> { base_selection }, foreign_key: :projekt_phase_id, class_name: "Proposal"

  after_create :create_map_location

  def phase_activated?
    active?
  end

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
    proposals.for_public_render.count
  end

  def selectable_by_users?
    feature?("resource.users_can_create_proposals")
  end

  def selectable_by_admins_only?
    !selectable_by_users?
  end

  def settings_categories
    %w[form_author user_functions]
  end

  def setting_pages
    %w[duration naming restrictions form_author user_functions]
  end

  def admin_nav_bar_items
    setting_pages + %w[projekt_labels sentiments map]
  end

  def safe_to_destroy?
    proposals.empty?
  end

  private

    def phase_specific_permission_problems(user, location)
      return :organization if user.organization? && location == :votes_component
    end
end
