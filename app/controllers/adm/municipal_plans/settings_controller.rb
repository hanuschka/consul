class Adm::MunicipalPlans::SettingsController < Adm::MunicipalPlans::BaseController
  before_action :authorize_settings, :load_breadcrumbs

  def show
  end

  def dashboard
  end

  def contact_persons
  end

  private

    def authorize_settings
      authorize [:adm, :municipal_plans, :setting], :show?
    end

    def load_breadcrumbs
      @breadcrumbs = [{ name: t("adm.municipal_plans.settings.title"), icon: "settings" }]
    end
end
