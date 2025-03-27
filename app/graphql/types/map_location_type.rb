module Types
  class MapLocationType < Types::BaseObject
    field :id, ID, null: false
    field :latitude, Float, null: true
    field :longitude, Float, null: true
    field :zoom, Integer, null: true
    field :shape, String, null: true
  end
end
