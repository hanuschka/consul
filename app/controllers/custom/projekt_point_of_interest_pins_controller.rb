class ProjektPointOfInterestPinsController < ApplicationController
  include MapLocationAttributes

  before_action :set_projekt_phase
  before_action :set_pin, only: [:show, :edit, :update, :destroy]
  before_action :authenticate_user!
  skip_authorization_check

  def new
    @pin = @projekt_phase.projekt_point_of_interest_pins.build
    @categories = @projekt_phase.projekt_point_of_interest_categories
  end

  def create
    @pin = @projekt_phase.projekt_point_of_interest_pins.new(pin_params)
    @pin.author = current_user

    if @pin.save
      redirect_to @projekt_phase.url,  notice: t("custom.projekt_phases.point_of_interest_phases.pins.create.notice")
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @pin.update(pin_params)
      redirect_to projekt_phase_path(@projekt_phase),
                  notice: t("custom.projekt_phases.point_of_interest_phases.pins.update.notice")
    else
      render :edit
    end
  end

  def destroy
    @pin.destroy
    redirect_to projekt_phase_path(@projekt_phase),
                notice: t("custom.projekt_phases.point_of_interest_phases.pins.destroy.notice")
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

    # def authorize_pin_creation
    #   unless @projekt_phase.current? && can?(:create, ProjektPointOfInterestPin)
    #     redirect_back alert: t("custom.projekt_phases.point_of_interest_phases.pins.create.error"), fallback_location: @projekt_phase.projekt.page.url
    #   end
    # end
end
