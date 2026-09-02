class MapDataController < ApplicationController
  skip_authorization_check

  SOURCE_SERVICES = {
    "point_of_interest_phase" => MapData::PointOfInterestPhase,
    "budget_phase" => MapData::BudgetPhase,
    "proposal_phase" => MapData::ProposalPhase
  }.freeze

  MAX_REQUESTED_PHASES = 50

  def show
    service_class = SOURCE_SERVICES[params[:source].to_s]

    if service_class.blank?
      head :bad_request and return
    end

    projekt_phases = requested_projekt_phases

    if projekt_phases.nil?
      head :not_found and return
    end

    feature_collections = projekt_phases.map do |projekt_phase|
      service_class.call(**service_params(service_class, projekt_phase))
    end

    render json: aggregate_feature_collections(feature_collections)
  end

  private

    def requested_projekt_phases
      if params[:projekt_phase_ids].present?
        ProjektPhase
          .where(id: params[:projekt_phase_ids].to_s.split(",").first(MAX_REQUESTED_PHASES))
          .includes(:settings, :projekt)
          .select { |phase| phase.name == params[:source].to_s }
          .select { |phase| map_data_visible?(phase) }
      else
        projekt_phase = ProjektPhase.find_by(id: params[:projekt_phase_id])

        return nil if projekt_phase.blank?

        map_data_visible?(projekt_phase) ? [projekt_phase] : []
      end
    end

    # Same gate the projekt page applies when rendering phase maps: the phase's
    # own map feature must be on for everyone, and hidden/inactive phases are
    # only served to admins/PMs (mirroring the footer phase tabs).
    def map_data_visible?(projekt_phase)
      return false if !projekt_phase.resource_map_enabled?
      return true if projekt_phase.publicly_visible?

      helpers.show_admin_controls_for_projekt?(projekt_phase.projekt)
    end

    def aggregate_feature_collections(feature_collections)
      features = feature_collections.flat_map do |collection|
        collection[:features] || collection["features"] || []
      end

      { type: "FeatureCollection", features: features }
    end

    def service_params(service_class, projekt_phase)
      case service_class.name
      when "MapData::PointOfInterestPhase"
        {
          projekt_phase: projekt_phase,
          category_ids: params[:category_ids]
        }
      when "MapData::BudgetPhase"
        {
          projekt_phase: projekt_phase,
          filter: params[:filter],
          search: params[:search],
          projekt_label_ids: params[:projekt_label_ids],
          sentiment_id: params[:sentiment_id]
        }
      when "MapData::ProposalPhase"
        {
          projekt_phase: projekt_phase,
          search: params[:search],
          projekt_label_ids: params[:projekt_label_ids],
          sentiment_id: params[:sentiment_id],
          my_posts_user_id: my_posts_user_id
        }
      end
    end

    def my_posts_user_id
      return nil if params[:my_posts_filter] != "true"

      current_user&.id
    end
end
