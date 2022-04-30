class ProjektPhase::CommentPhase < ProjektPhase
  def phase_activated?
    active?
  end

  def phase_info_activated?
    info_active?
  end

  def name
    'comment_phase'
  end

  def resources_name
    'comments'
  end
end
