class Api::IframesController < Api::BaseController
  before_action :find_projekt_phase, only: [:show, :update]

  def show
    check_read_access!
    serialized_iframe = IframeSerializer.new(@projekt_phase).serialize

    render json: { data: { iframe: serialized_iframe } }
  end

  def update
    check_admin_access!

    if params[:iframe]
      if params[:iframe][:iframe_url].present?
        update_or_create_setting("option.iframe.url", params[:iframe][:iframe_url])
      end

      if params[:iframe][:iframe_height].present?
        update_or_create_setting("option.iframe.height", params[:iframe][:iframe_height])
      end
    end

    serialized_iframe = IframeSerializer.new(@projekt_phase).serialize

    render json: { data: { iframe: serialized_iframe } }
  end

  private

  def find_projekt_phase
    @projekt_phase = ProjektPhase::IframePhase.find(params[:id])
  end

  def update_or_create_setting(key, value)
    setting = @projekt_phase.settings.find_or_initialize_by(key: key)
    setting.value = value
    setting.save
  end
end
