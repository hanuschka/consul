class ProjektEvaluations::ToggleSectionVisibilityService < ApplicationService
  def initialize(projekt_phase:, section_key:, visible:)
    @projekt_phase = projekt_phase
    @section_key = section_key.to_s
    @visible = ActiveModel::Type::Boolean.new.cast(visible) ? true : false
  end

  def call
    return false if !ProjektPhaseEvaluationVisibility::SECTION_KEYS.include?(@section_key)

    record = @projekt_phase.projekt_phase_evaluation_visibility ||
      @projekt_phase.build_projekt_phase_evaluation_visibility

    record.update!("show_#{@section_key}" => @visible)
  end
end
