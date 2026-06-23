class Adm::Dashboard::StatPillsComponent < ApplicationComponent
  delegate :number_with_delimiter, to: :helpers

  attr_reader :stats

  def initialize(stats: [])
    @stats = stats
  end

  def render?
    stats.any?
  end

  def formatted_stat_value(stat)
    value = stat[:value]
    value.is_a?(Numeric) ? number_with_delimiter(value) : value.to_s
  end
end
