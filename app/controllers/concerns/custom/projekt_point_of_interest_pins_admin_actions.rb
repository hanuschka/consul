module ProjektPointOfInterestPinsAdminActions
  extend ActiveSupport::Concern

  included do
    before_action :set_projekt_phase
    before_action :set_pin, only: [:show, :edit, :update, :destroy]
  end


  def show
  end

  # def edit
  # end

  # def update
  #   if @pin.update(pin_params)
  #     redirect_to admin_projekt_phase_projekt_point_of_interest_pins_path(@projekt_phase),
  #                 notice: t("custom.admin.projekt_phases.point_of_interest_phases.pins.update.notice")
  #   else
  #     render :edit
  #   end
  # end

  def destroy
    @pin.destroy
    redirect_to admin_projekt_phase_projekt_point_of_interest_pins_path(@projekt_phase),
                notice: t("custom.admin.projekt_phases.point_of_interest_phases.pins.destroy.notice")
  end

  private

    def set_projekt_phase
      @projekt_phase = ProjektPhase.find(params[:projekt_phase_id])
    end

    def set_pin
      @pin = @projekt_phase.projekt_point_of_interest_pins.find(params[:id])
    end
end
