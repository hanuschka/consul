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
      "#3969AC",
      "#E68310",
      "#11A579",
      "#CF1C90",
      "#F2B701",
      "#008695",
      "#E73F74",
      "#80BA5A",
      "#7F3C8D",
      "#F97B72",
      "#2F8AC4",
      "#DAA51B",
      "#764E9F",
      "#52BCA3"
    ]
  end

  def title
    I18n.t("stats.by_age")
  end
end
