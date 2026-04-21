class ProjektPhase::ArgumentPhase < ProjektPhase
  has_many :projekt_arguments, foreign_key: :projekt_phase_id,
    dependent: :destroy, inverse_of: :projekt_phase

  def title
    phase_tab_name.presence || I18n.t("custom.admin.projekt_phases.projekt_arguments.projekt_phase_default_title")
  end

  def name
    "argument_phase"
  end

  def resources_name
    "projekt_arguments"
  end

  def default_order
    4
  end

  def resource_count
    projekt_arguments.count
  end

  def customizable_email_templates
    [
      ["NotificationServiceMailer", "projekt_arguments"]
    ]
  end

  def admin_nav_bar_items
    %w[naming].push(resources_name, "email_templates")
  end

  def safe_to_destroy?
    projekt_arguments.empty?
  end

  private

    def phase_specific_permission_problems(user, location)
      return :organization if user.organization?
    end
end
