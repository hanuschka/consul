class Shared::ResourceMapComponent < ApplicationComponent
  def initialize(
    map_location: nil,
    resource_type: nil,
    marker_coordinates: [],
    projekt_phase: nil
  )
    @map_location = map_location
    @marker_coordinates = marker_coordinates
    @projekt_phase = projekt_phase
    @resource_type = resource_type
  end

  def resources_name
    debugger
    return "deficiency-reports" if @resource_type == DeficiencyReport
    return "budgets" if @resource_type == Budget::Investment

    @resource_type.name&.underscore&.pluralize
  end

  def render?
    return false if @projekt_phase.present? && !projekt_phase_feature?(@projekt_phase, "form.show_map")

    @marker_coordinates.present? || @map_location.present? || @projekt_phase&.map_location.present?
  end
end
