class ProjektPointOfInterestPins::CategorySetterComponent < ApplicationComponent
  delegate :toggle_element_in_array, to: :helpers

  def initialize(projekt_phase:)
    @projekt_phase = projekt_phase
    @categories = @projekt_phase.projekt_point_of_interest_categories
  end

  private

    def icon_unicode_for(category)
      AwesomeIcon.find_by(name: category.icon)&.unicode
    end
end
