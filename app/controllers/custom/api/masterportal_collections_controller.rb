class Api::MasterportalCollectionsController < Api::BaseController
  before_action :find_projekt_phase

  def index
    check_read_access!

    if phase_hidden_from_client?(@projekt_phase)
      raise ForbiddenError, "Access denied"
    end

    masterportal_collections = paginate(@projekt_phase.masterportal_collections.ordered)

    render json: {
      data: {
        masterportal_collections: MasterportalCollectionSerializer.serialize_collection(
          masterportal_collections,
          client: current_client
        )
      },
      pagination: pagination_meta(masterportal_collections)
    }
  end

  private

    def find_projekt_phase
      @projekt_phase = ProjektPhase.find(params[:projekt_phase_id])
    end
end
