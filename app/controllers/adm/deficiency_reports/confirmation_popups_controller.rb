class Adm::DeficiencyReports::ConfirmationPopupsController < Adm::DeficiencyReports::BaseController
  before_action :authorize_settings, :load_breadcrumbs
  before_action :load_confirmation_popup

  def edit
    @confirmation_popup.answers.build if @confirmation_popup.answers.empty?
  end

  def update
    if @confirmation_popup.update(confirmation_popup_params)
      redirect_to edit_adm_deficiency_reports_confirmation_popup_path,
        notice: t(".success")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

    def load_confirmation_popup
      @confirmation_popup = DeficiencyReport::ConfirmationPopup.current
    end

    def authorize_settings
      authorize [:adm, :deficiency_reports, :setting]
    end

    def load_breadcrumbs
      @breadcrumbs = [
        { name: t("adm.deficiency_reports.settings.title"),
          url: adm_deficiency_reports_settings_path,
          icon: "settings" },
        { name: t("adm.deficiency_reports.confirmation_popups.edit.title") }
      ]
    end

    def confirmation_popup_params
      params.require(:deficiency_report_confirmation_popup).permit(
        :enabled, :question,
        answers_attributes: [:id, :_destroy, :label, :behavior, :flash_notice, :position]
      )
    end
end
