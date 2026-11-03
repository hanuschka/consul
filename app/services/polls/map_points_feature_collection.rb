class Polls::MapPointsFeatureCollection < ApplicationService
  def initialize(question, export: false)
    @question = question
    @export = export
  end

  def call
    {
      "type" => "FeatureCollection",
      "features" => map_points.map { |map_point| feature(map_point) }
    }
  end

  def coordinates
    map_points.map { |map_point| [map_point.latitude, map_point.longitude] }
  end

  private

    def feature(map_point)
      feature = map_point.to_feature
      return feature unless @export

      feature["properties"].merge!(
        "context_title" => map_point.answer.question.context_title,
        "created_at" => map_point.created_at.iso8601
      )
      feature
    end

    def questions
      @export ? [@question, *@question.contexted_variants] : [@question]
    end

    def map_points
      @map_points ||= Poll::Answer::MapPoint
        .for_question(questions)
        .includes(answer: { question: [:context, { parent_question: :context }] })
        .order(:id)
        .to_a
    end
end
