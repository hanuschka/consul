class ProjektPhase::IframePhase < ProjektPhase
  def phase_activated?
    active?
  end

  def name
    "iframe_phase"
  end

  def resources_name
    "iframe"
  end

  def resource_count
    1
  end

  def admin_nav_bar_items
    %w[duration naming restrictions general_settings]
  end

  def safe_to_destroy?
    true
  end
end
