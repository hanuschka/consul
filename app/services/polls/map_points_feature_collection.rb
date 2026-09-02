class Polls::MapPointsFeatureCollection < ApplicationService
  def initialize(question)
    @question = question
  end

  def call
    {
      "type" => "FeatureCollection",
      "features" => map_points.map(&:to_feature)
    }
  end

  def coordinates
    map_points.map { |map_point| [map_point.latitude, map_point.longitude] }
  end

  private

    def map_points
      @map_points ||= Poll::Answer::MapPoint.for_question(@question).order(:id).to_a
    end
end
