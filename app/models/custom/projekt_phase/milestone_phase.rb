class ProjektPhase::MilestonePhase < ProjektPhase
  def phase_activated?
    active?
  end

  def phase_info_activated?
    info_active?
  end

  def name
    'milestone_phase'
  end

  def resources_name
    'milestones'
  end
end
