class Api::PointOfInterestPinsController < Api::BaseController
  include Translatable
  include MapLocationAttributes

  before_action :find_projekt_phase, only: [:index, :create], if: -> { params[:projekt_phase_id].present? }
  before_action :find_pin, only: [:show, :update, :destroy]

  def index
    check_read_access!
    pins = if @projekt_phase.present?
      @projekt_phase.projekt_point_of_interest_pins
        .includes(:author, :projekt_point_of_interest_category, :projekt_phase, :projekt_phase, :map_location)
    else
      ProjektPointOfInterestPin.includes(:author, :projekt_point_of_interest_category, :projekt_phase, :projekt_phase, :map_location)
    end

    pins = paginate(pins.order(created_at: :asc))

    serialized_pins = PointOfInterestPinSerializer.serialize_collection(pins)

    render json: {
      data: { pins: serialized_pins },
      pagination: pagination_meta(pins)
    }
  end

  def create
    check_admin_access!
    find_projekt_phase unless @projekt_phase.present?
    pin = @projekt_phase.projekt_point_of_interest_pins.new(pin_params)
    pin.author = @current_client.content_author

    if pin.save
      serialized_pin = PointOfInterestPinSerializer.new(pin).serialize

      render json: { data: { pin: serialized_pin } }, status: 201
    else
      render json: { error: { messages: pin.errors.full_messages } }, status: 422
    end
  end

  def show
    check_read_access!
    serialized_pin = PointOfInterestPinSerializer.new(@pin).serialize

    render json: { data: { pin: serialized_pin } }
  end

  def update
    check_admin_access!
    @pin.assign_attributes(pin_params)

    if @pin.save
      serialized_pin = PointOfInterestPinSerializer.new(@pin).serialize

      render json: { data: { pin: serialized_pin } }
    else
      render json: { error: { messages: @pin.errors.full_messages } }, status: 422
    end
  end

  def destroy
    check_admin_access!
    if @pin.destroy
      render json: { message: "Pin destroyed" }
    else
      render json: { error: { messages: @pin.errors.messages } }, status: 422
    end
  end

  private

  def pin_params
    params.require(:projekt_point_of_interest_pin).permit(
      :description,
      :author_id,
      :projekt_point_of_interest_category_id,
      map_location_attributes: map_location_attributes
    )
  end

  def find_projekt_phase
    @projekt_phase = ProjektPhase::PointOfInterestPhase.find(params[:projekt_phase_id]) if params[:projekt_phase_id].present?
  end

  def find_pin
    @pin = ProjektPointOfInterestPin.includes(:author, :projekt_point_of_interest_category, :projekt_phase, :projekt_phase, :map_location).find(params[:id])
  end
end

