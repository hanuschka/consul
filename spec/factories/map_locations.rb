FactoryBot.define do
  factory :map_location do
    latitude  { 50.7956 }
    longitude { 7.2044 }
    zoom      { 12 }

    # MapLocation only infers the rendering library for mappables that hang off a projekt phase, and
    # the column is NOT NULL, so anything else has to say which one it uses.
    rendering_library { :leaflet }
  end
end
