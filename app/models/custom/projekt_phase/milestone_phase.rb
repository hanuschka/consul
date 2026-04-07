class ProjektPhase::MilestonePhase < ProjektPhase
  def name
    "milestone_phase"
  end

  def resources_name
    "milestones"
  end

  def default_order
    5
  end

  def resource_count
    milestones.count
  end

  def customizable_email_templates
    [
      ["NotificationServiceMailer", "new_projekt_milestone"]
    ]
  end

  def admin_nav_bar_items
    %w[naming general_settings milestones progress_bars email_templates]
  end

  def safe_to_destroy?
    milestones.empty? && progress_bars.empty?
  end

  private

    def phase_specific_permission_problems(user, location)
      :organization if user.organization?
    end
end
