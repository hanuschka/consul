class Admin::ProjektPointOfInterestPinsController < Admin::BaseController
  before_action :set_projekt_phase
  before_action :set_pin, only: [:show, :edit, :update, :destroy]

  def index
    @pins = @projekt_phase.projekt_point_of_interest_pins.ordered

    respond_to do |format|
      format.html
      format.csv { send_data @pins.to_csv, filename: "point_of_interest_pins-#{Date.today}.csv" }
    end
  end

  def show
  end

  def new
    @pin = @projekt_phase.projekt_point_of_interest_pins.new
  end

  def create
    @pin = @projekt_phase.projekt_point_of_interest_pins.new(pin_params)
    @pin.user = current_user

    if @pin.save
      redirect_to admin_projekt_phase_projekt_point_of_interest_pins_path(@projekt_phase),
                  notice: t("custom.admin.projekt_phases.point_of_interest_phases.pins.create.notice")
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @pin.update(pin_params)
      redirect_to admin_projekt_phase_projekt_point_of_interest_pins_path(@projekt_phase),
                  notice: t("custom.admin.projekt_phases.point_of_interest_phases.pins.update.notice")
    else
      render :edit
    end
  end

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

    def pin_params
      params.require(:projekt_point_of_interest_pin).permit(
        :title,
        :description,
        :latitude,
        :longitude,
        :projekt_point_of_interest_category_id
      )
    end
end
