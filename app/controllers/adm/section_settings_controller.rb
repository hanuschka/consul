class Adm::SectionSettingsController < Adm::BaseController
  before_action :set_current_section
  before_action :load_section_setting
  helper_method :section_label

  def index
    authorize [:adm, @section_setting]
    @breadcrumbs = [{ name: t("adm.section_settings.title"), icon: "tune" }]
  end

  def update
    authorize [:adm, @section_setting]
    @section_setting.author = current_user

    if @section_setting.update(section_setting_params)
      redirect_to adm_section_settings_path(section: @current_section),
                  notice: t("adm.section_settings.flash.updated")
    else
      @breadcrumbs = [{ name: t("adm.section_settings.title"), icon: "tune" }]
      render :index, status: :unprocessable_entity
    end
  end

  private

    def set_current_section
      @current_section = if params[:section].in?(SectionSetting::SECTIONS)
                           params[:section]
                         else
                           SectionSetting::SECTIONS.first
                         end
    end

    def load_section_setting
      @section_setting = SectionSetting.for_section(@current_section)
    end

    def section_setting_params
      params.require(:section_setting).permit(:intro_text, :notice_message, :notice_active)
    end

    def section_label(section)
      t("adm.section_settings.sections.#{section}")
    end
end
