class ProjektPhase::MitmachboxPhase < ProjektPhase
  def name
    "mitmachbox_phase"
  end

  def resources_name
    "mitmachbox"
  end

  def default_order
    16
  end

  def admin_nav_bar_items
    %w[duration naming mitmachbox_survey mitmachbox_deployments mitmachbox_results]
  end

  def customizable_email_templates
    []
  end

  def subscribable?
    false
  end

  def safe_to_destroy?
    true
  end

  def remote_survey_created?
    mitmachbox_survey_id.present?
  end
end
