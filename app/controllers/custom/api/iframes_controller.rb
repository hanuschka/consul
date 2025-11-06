class Api::IframesController < Api::BaseController
  before_action :find_projekt_phase, only: [:show, :update]

  def show
    check_read_access!
    serialized_iframe = IframeSerializer.new(@projekt_phase).serialize

    render json: { data: { iframe: serialized_iframe } }
  end

  def update
    check_admin_access!

    if params[:projekt_iframe]
      if params[:projekt_iframe][:url].present?
        update_or_create_setting("option.iframe.url", params[:projekt_iframe][:url])
      end

      if params[:projekt_iframe][:width].present?
        update_or_create_setting("option.iframe.width", params[:projekt_iframe][:width])
      end

      if params[:projekt_iframe][:height].present?
        update_or_create_setting("option.iframe.height", params[:projekt_iframe][:height])
      end
    end

    serialized_iframe = IframeSerializer.new(@projekt_phase).serialize

    render json: { data: { iframe: serialized_iframe } }
  end

  private

  def find_projekt_phase
    @projekt_phase = ProjektPhase::IframePhase.find(params[:projekt_phase_id])
  end

  def update_or_create_setting(key, value)
    setting = @projekt_phase.settings.find_or_initialize_by(key: key)
    setting.value = value
    setting.save
  end
end
