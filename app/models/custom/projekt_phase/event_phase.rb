class ProjektPhase::EventPhase < ProjektPhase
  has_many :projekt_events, foreign_key: :projekt_phase_id,
    dependent: :destroy, inverse_of: :projekt_phase

  def name
    "event_phase"
  end

  def resources_name
    "projekt_events"
  end

  def resource_count
    projekt_events.count
  end

  def customizable_email_templates
    [
      ["NotificationServiceMailer", "new_projekt_event"]
    ]
  end

  def admin_nav_bar_items
    %w[naming general_settings].push(resources_name, "email_templates")
  end

  def safe_to_destroy?
    projekt_events.empty?
  end

  private

    def phase_specific_permission_problems(user, location)
      return :organization if user.organization?
    end
end
