class ParticapationStats::TimelineComponent < ApplicationComponent
  def initialize(projekt_phase:)
    @projekt_phase = projekt_phase
  end

  def render?
    query.total_submissions > 0
  end

  def submissions_chart_data
    query.submissions_chart_data
  end

  def comments_chart_data
    query.comments_chart_data
  end

  def total_submissions
    query.total_submissions
  end

  def total_comments
    query.total_comments
  end

  private

    def query
      @query ||= ProjektPhaseStats::TimelineQuery.new(@projekt_phase)
    end
end
