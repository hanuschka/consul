class ProjektPhase::DebatePhase < ProjektPhase
  has_many :resources, -> { all }, foreign_key: :projekt_phase_id, class_name: "Debate",
                                   inverse_of: :projekt_phase, dependent: :destroy

  def debates
    resources
  end

  def name
    "debate_phase"
  end

  def resources_name
    "debates"
  end

  def default_order
    2
  end

  def resource_count
    debates.for_public_render.count
  end

  def selectable_by_admins_only?
    feature?("general.only_admins_create_debates")
  end

  def admin_nav_bar_items
    %w[duration naming restrictions settings projekt_labels sentiments]
  end

  def safe_to_destroy?
    debates.empty?
  end

  def after_hide
    debates.each(&:hide)
  end

  private

    def phase_specific_permission_problems(user, location)
      nil
    end
end
