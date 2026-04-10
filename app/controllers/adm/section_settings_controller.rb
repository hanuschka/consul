class Adm::SectionSettingsController < Adm::BaseController
  before_action :validate_section_param!
  before_action :load_section_setting
  helper_method :section_label

  def edit
    @breadcrumbs = section_breadcrumbs
  end

  def update
    @section_setting.author = current_user

    if @section_setting.update(section_setting_params)
      redirect_to edit_adm_section_setting_path(@section_setting.section),
                  notice: t("adm.section_settings.flash.updated")
    else
      @breadcrumbs = section_breadcrumbs
      render :edit, status: :unprocessable_entity
    end
  end

  private

    def load_section_setting
      @section_setting = SectionSetting.for_section(params[:section])
      authorize [:adm, @section_setting]
    end

    def section_breadcrumbs
      [
        { name: t("adm.section_settings.title"), icon: "tune" },
        { name: section_label(@section_setting.section) }
      ]
    end

    def section_setting_params
      params.require(:section_setting).permit(:intro_text, :notice_message, :notice_active)
    end

    def validate_section_param!
      raise ActiveRecord::RecordNotFound unless SectionSetting::SECTIONS.include?(params[:section])
    end

    def section_label(section)
      t("adm.section_settings.sections.#{section}")
    end
end
