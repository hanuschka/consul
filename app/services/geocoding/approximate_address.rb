module Geocoding::ApproximateAddress
  # A geocoding result's address parts composed into the one line a person reads:
  # the street and its number, then the postcode and the closest name the result
  # carries for where that is. Nominatim's own display_name runs to seven parts and
  # names the country in it, which is a sentence about a place rather than an
  # address for one.
  #
  # Takes the `address` hash of a result — Geocoder's #data["address"], which is
  # what MapLocation stores as geocoder_data — rather than a result or a record, so
  # a stored lookup and a fresh one are composed the same way.
  LOCALITY_KEYS = %w[neighbourhood suburb village town city].freeze
  STREET_KEYS = %w[road house_number].freeze

  module_function

  def call(address_parts)
    return if address_parts.blank?

    locality = LOCALITY_KEYS.filter_map { |key| address_parts[key] }.join(", ")
    street = STREET_KEYS.filter_map { |key| address_parts[key] }.join(" ")

    "#{street}, #{address_parts["postcode"]} #{locality}"
  end
end
