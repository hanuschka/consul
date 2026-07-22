class PhaseEvaluationVisibility::Selector
  def self.for_phase(projekt_phase)
    visibility = projekt_phase.projekt_phase_evaluation_visibility
    return PhaseEvaluationVisibility::EmptySelector.new if visibility.blank?

    new(visibility)
  end

  def initialize(visibility)
    @visibility = visibility
  end

  def include_phase?(_phase_id)
    @visibility.any_visible?
  end

  def include_section?(_phase_id, section)
    @visibility.include_section?(section)
  end

  def include_report?
    false
  end

  def any_visible?
    @visibility.any_visible?
  end
end
