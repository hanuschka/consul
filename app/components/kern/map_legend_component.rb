class Kern::MapLegendComponent < ApplicationComponent
  def initialize(show_imported:)
    @show_imported = show_imported
  end

  def render?
    @show_imported
  end

  private

    attr_reader :show_imported
end
