class Sidebar::Filters::PhasesCardComponent < ApplicationComponent
  def initialize(phases:, selected_phase_type:)
    @phases = phases
    @selected_phase_type = selected_phase_type
  end
end
