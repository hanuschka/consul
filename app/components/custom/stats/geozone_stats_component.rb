class Stats::GeozoneStatsComponent < ApplicationComponent
  def initialize(stats:)
    @stats = stats
  end

  def render?
    @stats.geozone?
  end

  def geozone_data
    @stats.participants_by_geozone.reject { |_, v| v[:count].zero? }
  end

  def labels
    geozone_data.keys
  end

  def values
    geozone_data.values.map { |v| v[:count] }
  end

  def title
    I18n.t("stats.by_geozone")
  end
end
