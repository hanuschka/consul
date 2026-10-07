class ProposalAiDraft::LocationLookupService < ApplicationService
  # A place named in the citizen's words, found on the map inside the phase's own
  # area — or nothing. Answers the place rather than writing it: the web form shows
  # the pin on the map it is editing, but a chat has no map, so over WhatsApp the
  # place is put to the citizen before it goes anywhere near their contribution.
  #
  # The first result inside the area rather than the first result: the geocoder
  # is asked to stay inside it, and the answer is checked anyway (see PinArea).
  #
  # String-keyed because WhatsApp parks the answer in the conversation's jsonb
  # context until the citizen has said yes to it.
  def initialize(projekt_phase:, location_name:)
    @projekt_phase = projekt_phase
    @location_name = location_name
  end

  def call
    return if @location_name.blank?

    result = search_results.find { |candidate| area.contains?(*candidate.coordinates) }

    return if result.blank?

    latitude, longitude = result.coordinates

    {
      "latitude" => latitude,
      "longitude" => longitude,
      "name" => ::Polls::MapPointAddress.place_name(result)
    }
  rescue StandardError => e
    Rails.logger.error("[ProposalAiDraft] LocationLookupService failed: #{e.message}")

    nil
  end

  private

    def area
      @area ||= ::ProposalAiDraft::PinArea.new(@projekt_phase)
    end

    def search_results
      ::Geocoding::LocalSearchService.call(
        query: @location_name,
        latitude: area.latitude,
        longitude: area.longitude,
        radius_km: area.radius_km
      )
    end
end
