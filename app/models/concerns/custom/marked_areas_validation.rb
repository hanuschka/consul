module MarkedAreasValidation
  extend ActiveSupport::Concern

  included do
    attr_accessor :skip_marked_areas_check

    validate :map_features_inside_marked_areas, unless: :skip_marked_areas_check
  end

  private

    def map_features_inside_marked_areas
      return unless map_location_placed_or_moved?

      phase = projekt_phase
      return if phase.blank? || !phase.map_features_restricted_to_marked_areas?

      boundary = phase.map_boundary

      if !boundary.usable?
        report_untestable_marked_areas(phase)
        return
      end

      return if boundary.contains_features?(map_location.features)

      errors.add(:base, :map_features_outside_marked_areas)
    end

    def map_location_placed_or_moved?
      return false if map_location.blank? || map_location.marked_for_destruction?

      map_location.new_record? || map_location.features_changed?
    end

    def report_untestable_marked_areas(phase)
      return if !defined?(Sentry)

      Sentry.capture_message(
        "Marked areas not checked: GEOS is unavailable on this host",
        level: :warning,
        extra: { resource_class: self.class.name, projekt_phase_id: phase.id }
      )
    end
end
