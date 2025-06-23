class ProjektPointOfInterestPinsController < ApplicationController
  include MapLocationAttributes

  before_action :set_projekt_phase
  before_action :set_pin, only: [:json_data]
  before_action :authenticate_user!, except: [:json_data]

  skip_authorization_check only: [:json_data]

  def new
    @pin = @projekt_phase.projekt_point_of_interest_pins.build
    authorize! :create, @pin
  end

  def create
    @pin = @projekt_phase.projekt_point_of_interest_pins.new(pin_params)
    @pin.author = current_user

    authorize! :create, @pin

    if @pin.save
      redirect_to @projekt_phase.url,  notice: t("custom.projekt_phases.point_of_interest_phases.pins.create.notice")
    else
      render :new
    end
  end

  def json_data
    render json: {
      category: @pin.projekt_point_of_interest_category.as_json(only: [:name, :color, :icon])
    }
  end

  private

    def set_projekt_phase
      @projekt_phase = ProjektPhase.find(params[:projekt_phase_id])
    end

    def set_pin
      @pin = @projekt_phase.projekt_point_of_interest_pins.find(params[:id])
    end

    def pin_params
      params.require(:projekt_point_of_interest_pin).permit(
        :projekt_point_of_interest_category_id,
        map_location_attributes: map_location_attributes
      )
    end
end
