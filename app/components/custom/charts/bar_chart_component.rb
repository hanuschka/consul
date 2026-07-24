class Charts::BarChartComponent < ApplicationComponent
  def initialize(title:, labels:, values:, orientation: "vertical", colors: nil, use_percentage: false, show_labels_in_bars: false, show_legend: false)
    @title = title
    @labels = labels
    @values = values
    @orientation = orientation
    @colors = colors
    @use_percentage = use_percentage
    @show_labels_in_bars = show_labels_in_bars
    @show_legend = show_legend
  end

  def render?
    @labels.any? && @values.any?
  end

  def labels_json
    @labels.to_json
  end

  def values_json
    display_values.to_json
  end

  def colors_json
    @colors&.to_json
  end

  def use_percentage?
    @use_percentage
  end

  def show_labels_in_bars?
    @show_labels_in_bars
  end

  def show_legend?
    @show_legend
  end

  private

    def display_values
      return @values unless @use_percentage

      total = @values.sum.to_f
      return @values if total.zero?

      @values.map { |v| (v / total * 100).round(1) }
    end
end
