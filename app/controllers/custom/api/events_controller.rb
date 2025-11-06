class Api::EventsController < Api::BaseController
  include ImageAttributes

  before_action :find_projekt_phase, only: [:create]
  before_action :find_projekt_event, only: [:show, :update, :destroy]

  def create
    check_admin_access!
    projekt_event = @projekt_phase.projekt_events.new(projekt_event_params)

    if projekt_event.save
      serialized_projekt_event = EventSerializer.new(projekt_event).serialize

      render json: { data: { projekt_event: serialized_projekt_event } }, status: 201
    else
      render json: { error: { messages: projekt_event.errors.full_messages } }, status: 422
    end
  end

  def show
    check_read_access!
    serialized_projekt_event = EventSerializer.new(@projekt_event).serialize

    render json: { data: { projekt_event: serialized_projekt_event } }
  end

  def update
    check_admin_access!
    if @projekt_event.update(projekt_event_params)
      serialized_projekt_event = EventSerializer.new(@projekt_event).serialize

      render json: { data: { projekt_event: serialized_projekt_event } }
    else
      render json: { error: { messages: @projekt_event.errors.full_messages } }, status: 422
    end
  end

  def destroy
    check_admin_access!
    if @projekt_event.destroy
      render json: { message: "Projekt event destroyed" }
    else
      render json: { error: { messages: @projekt_event.errors.messages } }, status: 422
    end
  end

  private

  def projekt_event_params
    params.require(:projekt_event).permit(
      :title,
      :description,
      :summary,
      :datetime,
      :end_datetime,
      :location,
      :weblink,
      :open_ended
    )
  end

  def find_projekt_phase
    @projekt_phase = ProjektPhase::EventPhase.find(params[:projekt_phase_id])
  end

  def find_projekt_event
    @projekt_event = ProjektEvent.find(params[:id])
  end
end

