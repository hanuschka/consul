FactoryBot.define do
  factory :map_location do
    latitude  { 50.7956 }
    longitude { 7.2044 }
    zoom      { 12 }
    altitude  { 80 }

    # MapLocation only infers the rendering library for mappables that hang off a projekt phase, and
    # the column is NOT NULL, so anything else has to say which one it uses.
    rendering_library { :leaflet }

    # Reverse geocoding and the district lookup both reach outside the process on save; the model
    # exposes this flag to keep them out of the way in tests.
    skip_masterportal_geocoding { true }
  end
end
