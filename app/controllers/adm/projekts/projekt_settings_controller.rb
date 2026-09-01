class Adm::Projekts::ProjektSettingsController < Adm::Projekts::BaseController
  def update
    @projekt_setting = ProjektSetting.find(params[:id])

    authorize [:adm, :projekts, @projekt_setting]

    @projekt_setting.update!(projekt_setting_params)

    render json: { id: @projekt_setting.id, value: @projekt_setting.value }
  end

  private

    def projekt_setting_params
      params.require(:projekt_setting).permit(:value)
    end
end
