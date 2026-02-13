class Stats::AgeStatsComponent < ApplicationComponent
  def initialize(stats:)
    @stats = stats
  end

  def render?
    @stats.age?
  end

  def age_data
    @stats.participants_by_age.values.reject { |v| v[:count].zero? }
  end

  def labels
    age_data.map { |v| v[:range] }
  end

  def values
    age_data.map { |v| v[:count] }
  end

  def colors
    [
      "#6BA3D6",
      "#E89A6F",
      "#B0B0B0",
      "#7AB85C",
      "#FFCB4D",
      "#5682C4",
      "#B56A47",
      "#7A7A7A"
    ]
  end

  def title
    I18n.t("stats.by_age")
  end
end
