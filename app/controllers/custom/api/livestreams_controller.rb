class Api::LivestreamsController < Api::BaseController
  before_action :find_projekt_phase, only: [:index, :create], if: -> { params[:projekt_phase_id].present? }
  before_action :find_projekt_livestream, only: [:show, :update, :destroy]

  def index
    check_read_access!

    livestreams =
      if @projekt_phase.present?
        @projekt_phase
          .projekt_livestreams
          .includes(:projekt_phase)
      else
        ProjektLivestream.includes(:projekt_phase)
      end

    livestreams = paginate(livestreams.order(created_at: :asc))

    serialized_livestreams = LivestreamSerializer.serialize_collection(livestreams)

    render json: {
      data: { projekt_livestreams: serialized_livestreams },
      pagination: pagination_meta(livestreams)
    }
  end

  def create
    check_admin_access!
    find_projekt_phase unless @projekt_phase.present?
    projekt_livestream = @projekt_phase.projekt_livestreams.new(projekt_livestream_params)

    if projekt_livestream.save
      serialized_projekt_livestream = LivestreamSerializer.new(projekt_livestream).serialize

      render json: { data: { projekt_livestream: serialized_projekt_livestream } }, status: 201
    else
      render json: { error: { messages: projekt_livestream.errors.full_messages } }, status: 422
    end
  end

  def show
    check_read_access!
    serialized_projekt_livestream = LivestreamSerializer.new(@projekt_livestream).serialize

    render json: { data: { projekt_livestream: serialized_projekt_livestream } }
  end

  def update
    check_admin_access!
    if @projekt_livestream.update(projekt_livestream_params)
      serialized_projekt_livestream = LivestreamSerializer.new(@projekt_livestream).serialize

      render json: { data: { projekt_livestream: serialized_projekt_livestream } }
    else
      render json: { error: { messages: @projekt_livestream.errors.full_messages } }, status: 422
    end
  end

  def destroy
    check_admin_access!
    if @projekt_livestream.destroy
      render json: { message: "Projekt livestream destroyed" }
    else
      render json: { error: { messages: @projekt_livestream.errors.messages } }, status: 422
    end
  end

  private

  def projekt_livestream_params
    params.require(:projekt_livestream).permit(
      :url,
      :title,
      :description,
      :starts_at,
      :video_platform,
      :external_id,
      :preview_image_url
    )
  end

  def find_projekt_phase
    @projekt_phase = ProjektPhase::LivestreamPhase.find(params[:projekt_phase_id])
  end

  def find_projekt_livestream
    @projekt_livestream = ProjektLivestream.find(params[:id])
  end
end

