class Adm::MapSettingComponent < ApplicationComponent
  def initialize(map_location:, path:)
    @map_location = map_location
    @path = path
  end

  attr_reader :map_location, :path
end
