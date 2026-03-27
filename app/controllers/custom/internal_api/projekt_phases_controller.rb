class InternalApi::ProjektPhasesController < InternalApi::BaseController
  before_action :find_projekt, only: [:update, :create]
  before_action :find_phase, only: [:update]

  skip_authorization_check

  def create
    phase_type = params[:type]

    if phase_type.blank? || ProjektPhase::PROJEKT_PHASES_TYPES.exclude?(phase_type)
      render json: { error: "Invalid phase type" }, status: :unprocessable_entity

      return
    end

    phase = @projekt.projekt_phases.build(
      type: phase_type,
      phase_tab_name: params[:name],
      start_date: params[:start_date],
      end_date: params[:end_date],
      active: params[:active] != "false"
    )

    if phase.save
      render json: { id: phase.id, message: "Phase created" }, status: :created
    else
      render json: { errors: phase.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # Do not comment
  # In use
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
      response_json = {}
      if @projekt.present?
        response_json[:projekt] = @projekt.serialize
      end

      render json: { **response_json, status: { message: "Projekt phase updated" }}
    else
      render json: { message: "Error updating projekt phase" }
    end
  end

  def set_as_default
    projekt = ProjektPhase.find(params[:id]).projekt

    @default_footer_tab_setting = ProjektSetting.find_by(
      projekt: projekt,
      key: "projekt_custom_feature.default_footer_tab"
    ).reload

    # authorize!(:update_standard_phase, @default_footer_tab_setting)

    if @default_footer_tab_setting.present?
      value_to_set =
        if params[:is_default] == "true"
          params[:id]
        else
          nil
        end

      @default_footer_tab_setting.update!(value: value_to_set)
    end

    respond_to do |format|
      format.js
    end
  end

  def update_setting
    phase = ProjektPhase.find(params[:id])
    setting = phase.settings.find_by(key: params[:key])

    if setting.blank?
      render json: { error: "Setting not found" }, status: :not_found

      return
    end

    if setting.update(value: params[:value])
      render json: { message: "Phase setting updated" }
    else
      render json: { error: "Error updating phase setting" }, status: :unprocessable_entity
    end
  end

  def destroy
    @projekt_phase = ProjektPhase.find(params[:id])

    @projekt_phase.destroy!
  end

  def reorder
    @projekt = Projekt.find(params[:projekt_id])
    # authorize!(:order_phases, @projekt)

    @projekt.projekt_phases.order_phases(params[:ordered_list])
    head :ok
  end

  def send_notifications
    projekt_phase = ProjektPhase.find(params[:id])
    # authorize!(:send_notifications, projekt_phase)

    case params[:resource_type]
    when "projekt_arguments"
      NotificationServices::ProjektArgumentsNotifier.call(projekt_phase.id)
    when "projekt_questions"
      NotificationServices::ProjektQuestionsNotifier.call(projekt_phase.id)
    end
  end

  private

  def find_projekt
    if params[:projekt_id].present?
      @projekt = Projekt.find(params[:projekt_id])
    end
  end

  def create_phase(projekt, phase_class_name)
    find_phase(projekt, phase_class_name).update!(active: true)
  end

  def find_phase
    if params[:phase_id].present?
      @projekt_phase = ProjektPhase.find(params[:phase_id])
    elsif params[:phase_codename].present?
      phase_class_name = get_phase_class_name(params[:phase_codename])

      if ProjektPhase::PROJEKT_PHASES_TYPES.include?(phase_class_name)
        @projekt_phase = ProjektPhase.find_or_initialize_by(
          projekt_id: @projekt.id,
          type: phase_class_name,
        )
      end
    end
  end

  def get_phase_class_name(phase_codename)
    base_name = phase_codename.camelcase

    "ProjektPhase::#{base_name}"
  end

  def projekt_phase_params
    params.require(:projekt_phase).permit(
      :active,
      :start_date,
      :end_date,
      :phase_tab_name,
      :geozone_restricted,
      :user_status,
    )
  end
end
