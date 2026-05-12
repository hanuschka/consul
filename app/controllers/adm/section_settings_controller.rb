module Adm
  class SectionSettingsController < Adm::BaseController
    def update
      @section_setting = SectionSetting.for_section(params[:id])
      authorize [:adm, @section_setting]

      @section_setting.author = current_user

      if @section_setting.update(section_setting_params)
        redirect_back fallback_location: adm_root_path,
                      notice: t("adm.section_settings.flash.updated")
      else
        redirect_back fallback_location: adm_root_path,
                      alert: @section_setting.errors.full_messages.to_sentence
      end
    end

    private

      def section_setting_params
        params.require(:section_setting).permit(:intro_text, :notice_message, :notice_active)
      end
  end
end
