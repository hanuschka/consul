class ProjektPointOfInterestPins::CategorySetterComponent < ApplicationComponent
  delegate :toggle_element_in_array, to: :helpers

  def initialize(projekt_phase:)
    @projekt_phase = projekt_phase
    @categories = @projekt_phase.active_projekt_point_of_interest_categories.with_attached_icon_image
  end

  private

    attr_reader :categories

    def icon_unicode_for(category)
      AwesomeIcon.find_by(name: category.icon)&.unicode
    end

    def image_icon_url(category)
      return if !category.icon_image.attached?

      helpers.url_for(category.icon_image)
    end
end
