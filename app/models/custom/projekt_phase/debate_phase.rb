class ProjektPhase::DebatePhase < ProjektPhase
  def phase_activated?
    active?
  end

  def phase_info_activated?
    info_active?
  end

  def name
    'debate_phase'
  end

  def resources_name
    'debates'
  end
end
