class InternalApi::ProjektSettingsController < InternalApi::BaseController
  before_action :find_projekt
  before_action :find_projekt_setting

  skip_authorization_check

  def update
    if @projekt_setting.blank?
      return render json: { message: "Projekt setting not found" }, status: :not_found
    end

    # `update`, not `update_column`: a promoted setting mirrors its value onto
    # the projekts column from an after_save callback, which update_column
    # would skip — leaving the column stale (see Projekt::KEY_TO_COLUMN).
    if @projekt_setting.update(value: projekt_setting_params[:value])
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
    @projekt_setting = @projekt.projekt_settings.find_by(key: projekt_setting_params[:key])
  end

  def projekt_setting_params
    params.require(:projekt_setting).permit(
      :key, :value
    )
  end
end
