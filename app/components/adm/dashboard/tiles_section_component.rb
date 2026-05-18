class Adm::Dashboard::TilesSectionComponent < ApplicationComponent
  attr_reader :title, :hint, :icon, :tiles

  def initialize(title:, tiles:, hint: nil, icon: "dashboard")
    @title = title
    @hint = hint
    @icon = icon
    @tiles = tiles
  end

  def render?
    tiles.any?
  end
end
