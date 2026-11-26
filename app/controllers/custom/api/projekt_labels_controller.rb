class Api::ProjektLabelsController < Api::BaseController
  before_action :find_projekt_phase

  def index
    check_read_access!

    if phase_hidden_from_client?(@projekt_phase)
      raise ForbiddenError, "Access denied"
    end

    projekt_labels = paginate(@projekt_phase.projekt_labels.includes(:translations))

    render json: {
      data: { projekt_labels: ProjektLabelSerializer.serialize_collection(projekt_labels) },
      pagination: pagination_meta(projekt_labels)
    }
  end

  private

    def find_projekt_phase
      @projekt_phase = ProjektPhase.find(params[:projekt_phase_id])
    end
end
