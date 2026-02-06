class Charts::AreaChartComponent < ApplicationComponent
  def initialize(title:, labels:, values:, total: nil, color: "#6BA3D6")
    @title = title
    @labels = labels
    @values = values
    @total = total
    @color = color
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

  def total_value
    @total || @values.sum
  end
end
