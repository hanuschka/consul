class ProjektPointOfInterestPinsController < ApplicationController
  include MapLocationAttributes

  before_action :set_projekt_phase
  before_action :set_pin, only: [:show, :edit, :update, :destroy]
  before_action :authenticate_user!
  before_action :check_create_pin_acess, only: [:create, :new]

  skip_authorization_check

  def new
    @pin = @projekt_phase.projekt_point_of_interest_pins.build
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

    def check_create_pin_acess
      can_add_pin =
        if @projekt_phase.settings.find_by(key: "feature.general.only_admins_and_managers_can_create_pins").present?
          current_user&.administrator? || current_user&.projekt_manager?(@projekt_phase.projekt)
        else
          true
        end

      unless can_add_pin
        raise CanCan::AccessDenied.new
      end
    end

    # def authorize_pin_creation
    #   unless @projekt_phase.current? && can?(:create, ProjektPointOfInterestPin)
    #     redirect_back alert: t("custom.projekt_phases.point_of_interest_phases.pins.create.error"), fallback_location: @projekt_phase.projekt.page.url
    #   end
    # end
end
