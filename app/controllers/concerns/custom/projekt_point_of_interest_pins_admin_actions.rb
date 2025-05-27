module ProjektPointOfInterestPinsAdminActions
  extend ActiveSupport::Concern

  included do
    before_action :set_projekt_phase
    before_action :set_pin, only: [:show, :edit, :update, :destroy]
  end


  def show
  end

  def destroy
    authorize! :destroy, @pin

    if @pin.destroy!
      redirect_to polymorphic_path([@namespace, @projekt_phase], action: :projekt_point_of_interest_pins),
                  notice: t("custom.admin.projekt_phases.point_of_interest_phases.pins.destroy.notice")
    else
      redirect_to polymorphic_path([@namespace, @projekt_phase], action: :projekt_point_of_interest_pins),
                  alert: t("custom.admin.projekt_phases.point_of_interest_phases.pins.destroy.error")
    end
  end

  private

    def set_projekt_phase
      @projekt_phase = ProjektPhase.find(params[:projekt_phase_id])
    end

    def set_pin
      @pin = @projekt_phase.projekt_point_of_interest_pins.find(params[:id])
    end
end
