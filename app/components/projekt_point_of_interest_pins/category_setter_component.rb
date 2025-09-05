class ProjektPointOfInterestPins::CategorySetterComponent < ApplicationComponent
  delegate :toggle_element_in_array, to: :helpers

  def initialize(projekt_phase:)
    @projekt_phase = projekt_phase
    @categories = @projekt_phase.projekt_point_of_interest_categories
  end

  def category_button_color(category)
    if @categories.first == category
      category.color
    else
      "gray"
    end
  end
end
