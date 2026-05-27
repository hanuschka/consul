class Adm::Dashboard::HeaderRowComponent < ApplicationComponent
  delegate :number_with_delimiter, :kern_link_button, to: :helpers

  attr_reader :intro, :stats, :quick_links

  def initialize(intro: nil, stats: [], quick_links: [])
    @intro = intro
    @stats = stats
    @quick_links = quick_links
  end

  def render?
    intro.present? || stats.any? || quick_links.any?
  end

  def formatted_stat_value(stat)
    value = stat[:value]
    value.is_a?(Numeric) ? number_with_delimiter(value) : value.to_s
  end

  def stat_value_class(formatted_value)
    "adm-stat-card__value".tap do |klass|
      klass << " adm-stat-card__value--compact" if formatted_value.length >= 6
    end
  end
end
