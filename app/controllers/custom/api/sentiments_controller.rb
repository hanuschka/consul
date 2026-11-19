class Api::SentimentsController < Api::BaseController
  before_action :find_projekt_phase

  def index
    check_read_access!

    if phase_hidden_from_client?(@projekt_phase)
      raise ForbiddenError, "Access denied"
    end

    sentiments = paginate(@projekt_phase.sentiments.includes(:translations))

    render json: {
      data: { sentiments: SentimentSerializer.serialize_collection(sentiments) },
      pagination: pagination_meta(sentiments)
    }
  end

  private

    def find_projekt_phase
      @projekt_phase = ProjektPhase.find(params[:projekt_phase_id])
    end
end
