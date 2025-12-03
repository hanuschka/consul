class ParticapationStats::UserSegmentsComponent < ApplicationComponent
  def initialize(stats:)
    @stats = stats
  end

  def render?
    gender? || age? || geozone? || individual_group?
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

  def gender_cards
    [
      { key: "men", count: @stats.total_male_participants, percentage: @stats.male_percentage },
      { key: "women", count: @stats.total_female_participants, percentage: @stats.female_percentage },
      { key: "divers", count: @stats.total_other_gen_participants, percentage: @stats.other_gen_percentage }
    ]
  end

  def average_percentage
    100.0 / 3
  end

  def percentage_diff(percentage)
    diff = percentage - average_percentage
    return nil if diff.abs < 0.1

    sign = diff > 0 ? "+" : ""
    "#{sign}#{diff.round(1)}%"
  end

  def age_chart_data
    data = @stats.participants_by_age
    return { labels: [], values: [] } if data.blank?

    labels = data.values.map { |v| v[:range] }
    values = data.values.map { |v| v[:count] }
    { labels:, values: }
  end

  def geozone_chart_data
    data = @stats.participants_by_geozone
    return { labels: [], values: [] } if data.blank?

    sorted = data.sort_by { |_, v| -v[:count] }
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
      end.sort_by { |v| -v[:count] }

      {
        name: group.name,
        labels: values_data.map { |v| v[:name] },
        values: values_data.map { |v| v[:count] }
      }
    end
  end
end
