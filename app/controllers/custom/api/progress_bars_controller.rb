class Api::ProgressBarsController < Api::BaseController
  include Translatable

  before_action :find_projekt_phase, only: [:index, :create]
  before_action :find_progress_bar, only: [:show, :update, :destroy]

  def index
    check_read_access!
    progress_bars = paginate(@projekt_phase.progress_bars.order(:kind, :id))

    serialized = ProgressBarSerializer.serialize_collection(progress_bars)

    render json: {
      data: { progress_bars: serialized },
      pagination: pagination_meta(progress_bars)
    }
  end

  def create
    check_admin_access!
    progress_bar = @projekt_phase.progress_bars.new(progress_bar_params)

    if progress_bar.save
      serialized = ProgressBarSerializer.new(progress_bar).serialize

      render json: { data: { progress_bar: serialized } }, status: 201
    else
      render json: { error: { messages: progress_bar.errors.full_messages } }, status: 422
    end
  end

  def show
    check_read_access!
    serialized = ProgressBarSerializer.new(@progress_bar).serialize

    render json: { data: { progress_bar: serialized } }
  end

  def update
    check_admin_access!

    if @progress_bar.update(progress_bar_params)
      serialized = ProgressBarSerializer.new(@progress_bar).serialize

      render json: { data: { progress_bar: serialized } }
    else
      render json: { error: { messages: @progress_bar.errors.full_messages } }, status: 422
    end
  end

  def destroy
    check_admin_access!

    if @progress_bar.destroy
      render json: { message: "Progress bar destroyed" }
    else
      render json: { error: { messages: @progress_bar.errors.messages } }, status: 422
    end
  end

  private

  def progress_bar_params
    params.require(:progress_bar).permit(
      :kind,
      :percentage,
      :title,
      translation_params(ProgressBar)
    )
  end

  def find_projekt_phase
    @projekt_phase = ProjektPhase.find(params[:projekt_phase_id])
  end

  def find_progress_bar
    @progress_bar = ProgressBar.find(params[:id])
  end
end
