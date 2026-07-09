class Charts::PieChartComponent < ApplicationComponent
  def initialize(title:, labels:, values:, colors: nil, show_legend: true, labels_at_edges: false,
                 height: nil)
    @title = title
    @labels = labels
    @values = values
    @colors = colors
    @show_legend = show_legend
    @labels_at_edges = labels_at_edges
    @height = height
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

  def show_legend?
    @show_legend
  end

  def labels_at_edges?
    @labels_at_edges
  end

  def height_style
    return if @height.blank?

    @height.is_a?(Integer) ? "height: #{@height}px" : "height: #{@height}"
  end
end
