class ProjektPhaseStats::UserSegmentsQuery < ApplicationService
  def initialize(projekt_phase_or_stats)
    @stats = projekt_phase_or_stats
  end

  def call
    {
      gender_enabled: gender?,
      age_enabled: age?,
      geozone_enabled: geozone?,
      individual_group_enabled: individual_group?,
      gender: gender_chart_data,
      age: age_chart_data,
      geozone: geozone_chart_data,
      individual_groups: individual_groups_data
    }
  end

  def gender?
    @stats.gender?
  end

  def age?
    @stats.age?
  end

  def geozone?
    @stats.geozone?
  end

  def individual_group?
    @stats.individual_group?
  end

  def gender_chart_data
    return blank_chart unless @stats.gender?

    labels = []
    values = []

    male = @stats.total_male_participants.to_i
    female = @stats.total_female_participants.to_i
    other = @stats.total_other_gen_participants.to_i

    if male > 0
      labels << I18n.t("stats.men_percentage", percentage: "").strip
      values << male
    end
    if female > 0
      labels << I18n.t("stats.women_percentage", percentage: "").strip
      values << female
    end
    if other > 0
      labels << I18n.t("stats.other_gen_percentage", percentage: "").strip
      values << other
    end

    { labels:, values:, colors: ["#6BA3D6", "#E8A87C", "#C9CBCF"] }
  end

  def age_chart_data
    return blank_chart unless @stats.age?

    buckets = @stats.participants_by_age.values.reject { |v| v[:count].zero? }
    {
      labels: buckets.map { |v| v[:range] },
      values: buckets.map { |v| v[:count] }
    }
  end

  def geozone_chart_data
    data = @stats.participants_by_geozone
    return blank_chart if data.blank?

    filtered = data.reject { |_, v| v[:count].zero? }
    sorted = filtered.sort_by { |_, v| -v[:count] }
    labels = sorted.map { |k, _| k }
    values = sorted.map { |_, v| v[:count] }
    { labels:, values: }
  end

  def individual_groups_data
    @stats.soft_individual_groups.map do |group|
      values_data = group.individual_group_values.map do |value|
        {
          name: value.name,
          count: @stats.total_individual_group_value_participants(value)
        }
      end.reject { |v| v[:count].zero? }.sort_by { |v| -v[:count] }

      {
        name: group.name,
        labels: values_data.map { |v| v[:name] },
        values: values_data.map { |v| v[:count] }
      }
    end
  end

  private

    def blank_chart
      { labels: [], values: [] }
    end
end
