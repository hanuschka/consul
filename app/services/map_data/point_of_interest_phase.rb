class MapData::PointOfInterestPhase < ApplicationService
  def initialize(projekt_phase:, category_ids: nil)
    @projekt_phase = projekt_phase
    @category_ids = category_ids
  end

  def call
    return empty_collection if @projekt_phase.blank?

    map_locations = MapLocation.where(
      mappable_type: "ProjektPointOfInterestPin",
      mappable_id: @projekt_phase.projekt_point_of_interest_pins.select(:id)
    )

    MapLocation.enriched_feature_collection(
      map_locations,
      category_icons: selected_category_icons,
      extra_features: MasterportalPin.standalone_features_for_phase(@projekt_phase)
    )
  end

  private

    def selected_category_icons
      return nil if @category_ids.blank?

      ProjektPointOfInterestCategory.where(id: @category_ids).pluck(:icon)
    end

    def empty_collection
      { type: "FeatureCollection", features: [] }
    end
end
