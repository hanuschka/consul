# frozen_string_literal: true

class Polls::Questions::MapPointsAnswersComponent < Polls::Questions::AnswersComponent
  RENDERING_LIBRARY = "leaflet"

  def user_map_points
    @user_map_points ||= user_map_points_answer&.map_points&.to_a || []
  end

  def remaining_map_points
    [question.max_map_points - user_map_points.size, 0].max
  end

  def can_place_map_points?
    can?(:add_map_point, question)
  end

  def boundary_collection
    { "type" => "FeatureCollection", "features" => boundary_features }
  end

  def map_points_json
    user_map_points.map(&:to_feature).to_json
  end

  def counter_text
    map_points_t("remaining", count: remaining_map_points)
  end

  def map_points_t(key, **options)
    I18n.t("custom.polls.questions.map_points.#{key}", **options)
  end

  private

    def user_map_points_answer
      return if current_user.blank?

      @user_map_points_answer ||= question.answers.find_by(author: current_user)
    end

    def boundary_features
      features = question.map_location&.features

      return [] if features.blank?

      collection = features.is_a?(String) ? JSON.parse(features) : features

      Array(collection["features"]).map do |feature|
        feature.deep_dup.tap do |boundary|
          boundary["properties"] = (boundary["properties"] || {}).merge("poll_map_boundary" => true)
        end
      end
    rescue JSON::ParserError
      []
    end
end
