class Api::ProjektPhasesController < Api::BaseController
  before_action :find_projekt, only: [:update]
  before_action :find_phase, only: [:update]

  skip_authorization_check
  skip_forgery_protection

  def update
    if params[:geozone_restricted_street]
      street = RegisteredAddress::Street.by_user_input(
        name: params[:geozone_restricted_street][:street_name],
        plz: params[:geozone_restricted_street][:plz]
      )

      if street.present?
        @projekt_phase.registered_address_streets << street
      end
    end

    if @projekt_phase.update!(projekt_phase_params)
      render json: { projekt: @projekt.serialize, status: { message: "Projekt phase updated" }}
    else
      render json: { message: "Error updating projekt phase" }
    end
  end

  private

  def find_projekt
    @projekt = Projekt.find(params[:projekt_id])
  end

  def create_phase(projekt, phase_class_name)
    find_phase(projekt, phase_class_name).update!(active: true)
  end

  def find_phase
    phase_class_name = get_phase_class_name(params[:codename])

    if ProjektPhase::PROJEKT_PHASES_TYPES.include?(phase_class_name)
      @projekt_phase = ProjektPhase.find_or_initialize_by(
        projekt_id: @projekt.id,
        type: phase_class_name,
      )
    end
  end

  def get_phase_class_name(phase_codename)
    base_name = phase_codename.camelcase

    "ProjektPhase::#{base_name}"
  end

  def projekt_phase_params
    params.permit(
      :active,
      :start_date,
      :end_date,
      :phase_tab_name,
      :guest_participation_allowed,
      :verification_restricted,
      :geozone_restricted,
    )
  end
end
