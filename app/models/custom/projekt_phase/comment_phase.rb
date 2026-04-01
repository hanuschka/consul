class ProjektPhase::CommentPhase < ProjektPhase
  def name
    "comment_phase"
  end

  def resources_name
    "comments"
  end

  def default_order
    1
  end

  def resource_count
    comments.count
  end

  def customizable_email_templates
    [
      ["NotificationServiceMailer", "new_comment"]
    ]
  end

  def admin_nav_bar_items
    %w[duration naming restrictions comments email_templates]
  end

  def safe_to_destroy?
    comments.empty?
  end

  def comments_allowed?(current_user)
    selectable_by?(current_user)
  end

  private

    def phase_specific_permission_problems(user, location)
      nil
    end
end
