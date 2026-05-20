class PhaseEvaluationVisibility::EmptySelector
  def include_phase?(_phase_id)
    false
  end

  def include_section?(_phase_id, _section)
    false
  end

  def include_report?
    false
  end

  def any_visible?
    false
  end
end
