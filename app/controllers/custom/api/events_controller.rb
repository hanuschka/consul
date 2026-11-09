class Api::EventsController < Api::BaseController
  include ImageAttributes

  before_action :find_projekt_phase, only: [:index, :create], if: -> { params[:projekt_phase_id].present? }
  before_action :find_projekt_event, only: [:show, :update, :destroy]

  def index
    check_read_access!

    if @projekt_phase.present?
      if phase_hidden_from_client?(@projekt_phase)
        raise ForbiddenError, "Access denied"
      end

      events = @projekt_phase.projekt_events
        .includes(:projekt_phase, projekt_phase: :projekt)
    else
      events = ProjektEvent.includes(:projekt_phase, projekt_phase: :projekt)

      if current_client.public_data?
        events = restrict_to_public_phases(events)
      end
    end

    events = paginate(events.order(created_at: :asc))

    serialized_events = EventSerializer.serialize_collection(events)

    render json: {
      data: { events: serialized_events },
      pagination: pagination_meta(events)
    }
  end

  def create
    check_admin_access!
    find_projekt_phase unless @projekt_phase.present?
    projekt_event = @projekt_phase.projekt_events.new(projekt_event_params)

    if projekt_event.save
      process_image_with_base64(projekt_event, params[:projekt_event][:image_attributes])
      serialized_projekt_event = EventSerializer.new(projekt_event).serialize

      render json: { data: { projekt_event: serialized_projekt_event } }, status: 201
    else
      render json: { error: { messages: projekt_event.errors.full_messages } }, status: 422
    end
  rescue *SELF_RENDERED_ERRORS
    raise
  rescue StandardError => e
    render json: { error: { messages: [e.message] } }, status: 422
  end

  def show
    check_read_access!
    serialized_projekt_event = EventSerializer.new(@projekt_event).serialize

    render json: { data: { projekt_event: serialized_projekt_event } }
  end

  def update
    check_admin_access!
    if @projekt_event.update(projekt_event_params)
      process_image_with_base64(@projekt_event, params[:projekt_event][:image_attributes]) if params[:projekt_event]&.key?(:image_attributes)
      serialized_projekt_event = EventSerializer.new(@projekt_event).serialize

      render json: { data: { projekt_event: serialized_projekt_event } }
    else
      render json: { error: { messages: @projekt_event.errors.full_messages } }, status: 422
    end
  rescue *SELF_RENDERED_ERRORS
    raise
  rescue StandardError => e
    render json: { error: { messages: [e.message] } }, status: 422
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
      :open_ended,
      :language,
      :wheelchair_accessible,
      :accessible_toilet,
      :disabled_parking_nearby,
      :tactile_guidance_systems,
      :induction_loop_available,
      :assistance_dogs_welcome,
      :sign_language_interpreter
    )
  end

  def find_projekt_phase
    @projekt_phase = ProjektPhase::EventPhase.find(params[:projekt_phase_id])
  end

  def find_projekt_event
    @projekt_event = ProjektEvent.includes(:projekt_phase, projekt_phase: :projekt).find(params[:id])
  end
end

