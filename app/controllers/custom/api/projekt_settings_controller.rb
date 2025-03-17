class Api::ProjektSettingsController < Api::BaseController
  before_action :find_projekt
  before_action :find_projekt_setting

  skip_authorization_check

  def update
    if @projekt_setting.update_column(:value, projekt_setting_params[:value])
      render json: { message: "Projekt setting updated" }
    else
      render json: { message: "Error updating projekt setting" }
    end
  end

  private

  def find_projekt
    @projekt = Projekt.find(params[:projekt_id])
  end

  def find_projekt_setting
    @projekt_setting = @projekt.find_setting(projekt_setting_params[:key])
  end

  def projekt_setting_params
    params.require(:projekt_setting).permit(
      :key, :value
    )
  end
end
