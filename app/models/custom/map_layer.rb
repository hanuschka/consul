load Rails.root.join("app", "models", "map_layer.rb")

class MapLayer < ApplicationRecord
  # Only configuration API writes: projekt creation copies every default layer.
  audited if: ->(_map_layer) { Current.api_client.present? }
end
