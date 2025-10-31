class Api::ProjektPointOfInterestPinsController < Api::BaseController
  include MapLocationAttributes

  before_action :find_projekt_phase, only: [:create]
  before_action :find_pin, only: [:show, :update, :destroy]

  def create
    pin = @projekt_phase.projekt_point_of_interest_pins.new(pin_params)
    pin.api_client_created = @current_client

    if pin.save(context: :api)
      serialized_pin = ProjektPointOfInterestPinSerializer.new(pin).serialize

      render json: { data: { pin: serialized_pin } }, status: 201
    else
      render json: { error: { messages: pin.errors.full_messages } }, status: 422
    end
  end

  def show
    serialized_pin = ProjektPointOfInterestPinSerializer.new(@pin).serialize

    render json: { data: { pin: serialized_pin } }
  end

  def update
    @pin.api_client_last_updated = @current_client
    @pin.assign_attributes(pin_params)

    if @pin.save(context: :api)
      serialized_pin = ProjektPointOfInterestPinSerializer.new(@pin).serialize

      render json: { data: { pin: serialized_pin } }
    else
      render json: { error: { messages: @pin.errors.full_messages } }, status: 422
    end
  end

  def destroy
    if @pin.destroy
      render json: { message: "Pin destroyed" }
    else
      render json: { error: { messages: @pin.errors.messages } }, status: 422
    end
  end

  private

  def pin_params
    params.require(:projekt_point_of_interest_pin).permit(
      :author_id,
      :projekt_point_of_interest_category_id,
      :description,
      map_location_attributes: map_location_attributes
    )
  end

  def find_projekt_phase
    @projekt_phase = ProjektPhase::PointOfInterestPhase.find(params[:projekt_phase_id])
  end

  def find_pin
    @pin = ProjektPointOfInterestPin.find(params[:id])
  end
end

