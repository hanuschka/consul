class Adm::MunicipalPlans::SettingsController < Adm::MunicipalPlans::BaseController
  def show
    authorize [:adm, :municipal_plans, :setting], :show?

    @breadcrumbs = [{ name: t("adm.municipal_plans.settings.title"), icon: "settings" }]
  end
end
