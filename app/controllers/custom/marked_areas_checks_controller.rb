class MarkedAreasChecksController < ApplicationController
  MAX_FEATURES_LENGTH = 200_000

  skip_authorization_check only: :create

  def create
    projekt_phase = ProjektPhase.find(params[:id])

    render json: { inside: inside_marked_areas?(projekt_phase) }
  end

  private

    def inside_marked_areas?(projekt_phase)
      return true if !projekt_phase.map_features_restricted_to_marked_areas?

      boundary = projekt_phase.map_boundary
      return true if !boundary.usable?

      features = submitted_features
      return false if features.nil?

      boundary.contains_features?(features)
    end

    def submitted_features
      raw = params[:features].to_s
      return nil if raw.length > MAX_FEATURES_LENGTH

      parsed = JSON.parse(raw)
      parsed.is_a?(Hash) ? parsed : nil
    rescue JSON::ParserError
      nil
    end
end
