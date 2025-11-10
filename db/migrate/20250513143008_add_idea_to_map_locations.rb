class AddIdeaToMapLocations < ActiveRecord::Migration[6.1]
  def change
    add_reference :map_locations, :idea, foreign_key: true
  end
end
