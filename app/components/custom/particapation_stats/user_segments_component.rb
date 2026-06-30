class ParticapationStats::UserSegmentsComponent < ApplicationComponent
  def initialize(stats:)
    @stats = stats
  end

  def render?
    gender? || age? || geozone? || individual_group?
  end

  def gender?
    query.gender?
  end

  def age?
    query.age?
  end

  def geozone?
    query.geozone?
  end

  def individual_group?
    query.individual_group?
  end

  def geozone_chart_data
    query.geozone_chart_data
  end

  def individual_groups_data
    query.individual_groups_data
  end

  private

    def query
      @query ||= ProjektPhaseStats::UserSegmentsQuery.new(@stats)
    end
end
