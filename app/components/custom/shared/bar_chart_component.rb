class Shared::BarChartComponent < ApplicationComponent
  def initialize(title:, labels:, values:, orientation: "vertical", colors: nil)
    @title = title
    @labels = labels
    @values = values
    @orientation = orientation
    @colors = colors
  end

  def render?
    @labels.any? && @values.any?
  end

  def labels_json
    @labels.to_json
  end

  def values_json
    @values.to_json
  end

  def colors_json
    @colors&.to_json
  end
end

