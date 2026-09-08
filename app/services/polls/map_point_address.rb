class Polls::MapPointAddress
  # A pair of coordinates read back as a place a person recognises. There is nowhere
  # to keep it — poll_answer_map_points holds a latitude and a longitude and nothing
  # else — so it is asked for at the moment it is said and never stored.
  #
  # It exists for the chat. A pin dropped on the portal's map is confirmed by the
  # map itself; a pin sent to WhatsApp has to be confirmed in words, and the words
  # cannot be the numbers back again — a citizen has no way to tell 52.5163 from a
  # typo of it.
  #
  # Blank rather than an error for everything that can go wrong. The point is
  # already recorded by the time this is asked: the address is the courtesy line
  # over it, and a lookup that fails is a line the caller leaves out, never a
  # position refused. Nominatim's own service is one request a second and has no
  # timeout of its own here (config/initializers/geocoder.rb sets none), so the
  # timeout travels with the query rather than being left to the default.
  TIMEOUT_SECONDS = 3

  def initialize(latitude:, longitude:)
    @latitude = latitude
    @longitude = longitude
  end

  def call
    return if @latitude.blank? || @longitude.blank?

    result = reverse_geocode

    return if result.blank?

    composed = ::Geocoding::ApproximateAddress.call(result.data&.dig("address"))

    return composed if names_a_place?(composed)

    result.address.presence
  rescue StandardError => e
    Rails.logger.error("[Polls::MapPointAddress] lookup failed: #{e.message}")

    nil
  end

  private

    def reverse_geocode
      Geocoder.search(
        [@latitude.to_f, @longitude.to_f], timeout: TIMEOUT_SECONDS
      ).first
    end

    # A result carrying a postcode and nothing else composes to a line of
    # punctuation, which is worse than the long form it was meant to replace. Asked
    # of the composed line rather than of the parts, because what matters is whether
    # there is anything in it left to read.
    def names_a_place?(composed)
      composed.present? && composed.match?(/[[:alpha:]]/)
    end
end
