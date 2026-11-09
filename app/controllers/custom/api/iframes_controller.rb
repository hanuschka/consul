class Api::IframesController < Api::BaseController
  before_action :find_projekt_phase, only: [:show, :update]

  def show
    check_read_access!
    serialized_iframe = IframeSerializer.new(@projekt_phase).serialize

    render json: { data: { iframe: serialized_iframe } }
  end

  def update
    check_admin_access!

    ProjektPhaseSetting.transaction do
      iframe_params.each do |attribute, value|
        setting = @projekt_phase.settings.find_or_initialize_by(
          key: IframeSerializer::SETTING_KEYS.fetch(attribute.to_sym)
        )
        setting.update!(value: value.to_s)
      end
    end

    serialized_iframe = IframeSerializer.new(@projekt_phase.reload).serialize

    render json: { data: { iframe: serialized_iframe } }
  end

  private

  def iframe_params
    params.require(:projekt_iframe).permit(*IframeSerializer::SETTING_KEYS.keys)
  end

  def find_projekt_phase
    @projekt_phase = ProjektPhase::IframePhase.find(params[:projekt_phase_id])
  end
end
