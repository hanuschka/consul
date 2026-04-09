class Adm::SectionSettingsController < Adm::BaseController
  helper_method :section_label

  def edit
    @section_setting = SectionSetting.for_section(params[:section])
    authorize [:adm, @section_setting]

    @breadcrumbs = [
      { name: t("adm.section_settings.title"), icon: "tune" },
      { name: section_label(@section_setting.section) }
    ]
  end

  def update
    @section_setting = SectionSetting.for_section(params[:section])
    authorize [:adm, @section_setting]

    @section_setting.author = current_user

    if @section_setting.update(section_setting_params)
      redirect_to edit_adm_section_setting_path(@section_setting.section),
                  notice: t("adm.section_settings.flash.updated")
    else
      @breadcrumbs = [
        { name: t("adm.section_settings.title"), icon: "tune" },
        { name: section_label(@section_setting.section) }
      ]
      render :edit, status: :unprocessable_entity
    end
  end

  private

    def section_setting_params
      params.require(:section_setting).permit(:intro_text, :notice_message, :notice_active)
    end

    def section_label(section)
      t("adm.section_settings.sections.#{section}")
    end
end
