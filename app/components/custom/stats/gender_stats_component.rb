class Stats::GenderStatsComponent < ApplicationComponent
  def initialize(stats:)
    @stats = stats
  end

  def render?
    @stats.gender?
  end

  def labels
    result = []

    if @stats.total_male_participants > 0
      result << I18n.t("stats.men_percentage", percentage: "").strip
    end

    if @stats.total_female_participants > 0
      result << I18n.t("stats.women_percentage", percentage: "").strip
    end

    if @stats.total_other_gen_participants > 0
      result << I18n.t("stats.other_gen_percentage", percentage: "").strip
    end

    result
  end

  def values
    result = []

    if @stats.total_male_participants > 0
      result << @stats.total_male_participants
    end

    if @stats.total_female_participants > 0
      result << @stats.total_female_participants
    end

    if @stats.total_other_gen_participants > 0
      result << @stats.total_other_gen_participants
    end

    result
  end

  def colors
    ["#6BA3D6", "#E8A87C", "#C9CBCF"]
  end

  def title
    I18n.t("stats.by_gender")
  end
end
