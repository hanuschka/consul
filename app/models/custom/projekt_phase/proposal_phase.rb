class ProjektPhase::ProposalPhase < ProjektPhase
  def phase_activated?
    active?
  end

  def phase_info_activated?
    info_active?
  end

  def name
    'proposal_phase'
  end

  def resources_name
    'proposals'
  end
end
