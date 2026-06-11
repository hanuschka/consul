class Adm::Dashboard::TilesSectionComponent < ApplicationComponent
  attr_reader :title, :hint, :icon, :tiles, :stats

  def initialize(title:, tiles:, hint: nil, icon: "dashboard", stats: [])
    @title = title
    @hint = hint
    @icon = icon
    @tiles = tiles
    @stats = stats
  end

  def render?
    tiles.any?
  end
end
