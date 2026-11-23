class Api::PointOfInterestPinsController < Api::BaseController
  include Translatable
  include MapLocationAttributes

  TRANSLATED_ATTRIBUTES = %w[description].freeze

  PRELOADS = [
    :projekt_point_of_interest_category, :map_location, :translations, :masterportal_pin,
    { projekt_phase: [:translations, { projekt: { page: :translations } }] },
    { author: :organization }
  ].freeze

  before_action :find_projekt_phase, only: [:index, :create], if: -> { params[:projekt_phase_id].present? }
  before_action :find_pin, only: [:show, :update, :destroy]

  def index
    check_read_access!

    if @projekt_phase.present?
      check_phase_visible!(@projekt_phase)
    end

    pins =
      if @projekt_phase.present?
        @projekt_phase.projekt_point_of_interest_pins.includes(PRELOADS)
      elsif current_client.public_data?
        restrict_to_public_phases(ProjektPointOfInterestPin.includes(PRELOADS))
      else
        ProjektPointOfInterestPin.includes(PRELOADS)
      end

    pins = paginate(pins.order(created_at: :asc))

    serialized_pins = PointOfInterestPinSerializer.serialize_collection(pins, client: current_client)

    render json: {
      data: { pins: serialized_pins },
      pagination: pagination_meta(pins)
    }
  end

  def create
    check_admin_access!
    pin =@projekt_phase.projekt_point_of_interest_pins.new(pin_params.merge(external_reference_params))
    pin.author = @current_client.content_author
    translations = assign_requested_translations(pin, :projekt_point_of_interest_pin, TRANSLATED_ATTRIBUTES)

    if save_with_translations(pin, translations)
      serialized_pin = PointOfInterestPinSerializer.new(pin, client: current_client).serialize

      render json: { data: { pin: serialized_pin } }, status: 201
    else
      render_translated_record_errors(pin)
    end
  end

  def show
    check_read_access!
    check_phase_visible!(@pin.projekt_phase)

    serialized_pin = PointOfInterestPinSerializer.new(@pin, client: current_client).serialize

    render json: { data: { pin: serialized_pin } }
  end

  def update
    check_admin_access!
    @pin.assign_attributes(with_existing_map_location_id(@pin, pin_params))
    translations = assign_requested_translations(@pin, :projekt_point_of_interest_pin, TRANSLATED_ATTRIBUTES)

    if save_with_translations(@pin, translations)
      serialized_pin = PointOfInterestPinSerializer.new(@pin, client: current_client).serialize

      render json: { data: { pin: serialized_pin } }
    else
      render_translated_record_errors(@pin)
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
      :projekt_point_of_interest_category_id,
      map_location_attributes: map_location_attributes_api
    ).to_h
  end

  def external_reference_params
    params.require(:projekt_point_of_interest_pin).permit(:external_source, :external_id).to_h
  end

  def find_projekt_phase
    @projekt_phase = ProjektPhase::PointOfInterestPhase.find(params[:projekt_phase_id]) if params[:projekt_phase_id].present?
  end

  def find_pin
    @pin = ProjektPointOfInterestPin.includes(PRELOADS).find(params[:id])
  end
end
