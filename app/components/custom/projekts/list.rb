class Projekts::List < ApplicationComponent
  def initialize(projekts:, projekt_map_coordinates:)
    @projekts = projekts
    @projekt_map_coordinates = projekt_map_coordinates
  end
end
