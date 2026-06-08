class PhaseEvaluationVisibility::AdminSelector
  def include_phase?(_phase_id)
    true
  end

  def include_section?(_phase_id, _section)
    true
  end

  def include_report?
    true
  end

  def any_visible?
    true
  end
end
