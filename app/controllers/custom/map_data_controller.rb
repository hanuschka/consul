class MapDataController < ApplicationController
  skip_authorization_check

  SOURCE_SERVICES = {
    "point_of_interest_phase" => MapData::PointOfInterestPhase,
    "budget_phase" => MapData::BudgetPhase,
    "proposal_phase" => MapData::ProposalPhase
  }.freeze

  def show
    service_class = SOURCE_SERVICES[params[:source].to_s]

    if service_class.blank?
      head :bad_request and return
    end

    projekt_phase = ProjektPhase.find_by(id: params[:projekt_phase_id])

    if projekt_phase.blank?
      head :not_found and return
    end

    feature_collection = service_class.call(**service_params(service_class, projekt_phase))

    render json: feature_collection
  end

  private

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
