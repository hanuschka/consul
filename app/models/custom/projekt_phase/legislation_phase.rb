class ProjektPhase::LegislationPhase < ProjektPhase
  has_one :legislation_process, foreign_key: :projekt_phase_id, class_name: "Legislation::Process",
    dependent: :destroy, inverse_of: :projekt_phase

  after_create :create_legislation_process

  def name
    "legislation_phase"
  end

  def resources_name
    "legislation"
  end

  def default_order
    3
  end

  def admin_nav_bar_items
    %w[duration naming restrictions legislation_process_draft_versions]
  end

  def safe_to_destroy?
    legislation_process.blank?
  end

  def after_hide
    legislation_process&.hide
  end

  private

    def phase_specific_permission_problems(user, location)
      return :organization if user.organization?
    end

    def create_legislation_process
      return if legislation_process.present?

      ::Legislation::Process.create!(
        projekt_phase: self,
        title: projekt.name
      )
    end
end
