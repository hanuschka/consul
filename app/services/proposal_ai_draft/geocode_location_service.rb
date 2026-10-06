class ProposalAiDraft::GeocodeLocationService < ApplicationService
  # The web form's half: the place is looked up inside the phase's area and pinned
  # straight away, because the form shows the pin on its own map where the citizen
  # can move or remove it. WhatsApp only looks it up (LocationLookupService) and
  # asks first.
  #
  # Any mappable the drafting flows produce — a Proposal today, and a
  # Budget::Investment is Mappable the same way, which is why the keyword does
  # not name one of them.
  def initialize(mappable:, location_name:)
    @mappable = mappable
    @location_name = location_name
  end

  def call
    place = ::ProposalAiDraft::LocationLookupService.call(
      projekt_phase: @mappable.projekt_phase, location_name: @location_name
    )

    return if place.blank?
    return if outside_marked_areas?(place)

    MapLocation.create_pin!(
      mappable: @mappable, latitude: place["latitude"], longitude: place["longitude"]
    )
  rescue StandardError => e
    Rails.logger.error("[ProposalAiDraft] GeocodeLocationService failed: #{e.message}")
  end

  private

    def outside_marked_areas?(place)
      phase = @mappable.projekt_phase
      return false if phase.blank? || !phase.map_features_restricted_to_marked_areas?

      boundary = phase.map_boundary

      boundary.usable? && !boundary.contains?(place["latitude"], place["longitude"])
    end
end
