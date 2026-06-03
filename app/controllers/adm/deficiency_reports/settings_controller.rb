class Adm::DeficiencyReports::SettingsController < Adm::DeficiencyReports::BaseController
  before_action :authorize_settings, :load_breadcrumbs

  def show
  end

  def dashboard
  end

  def contact_persons
  end

  def naming
  end

  private

    def authorize_settings
      authorize [:adm, :deficiency_reports, :setting], :show?
    end

    def load_breadcrumbs
      @breadcrumbs = [{ name: t("adm.deficiency_reports.settings.title"), icon: "settings" }]
    end
end
