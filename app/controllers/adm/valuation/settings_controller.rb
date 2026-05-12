class Adm::Valuation::SettingsController < Adm::Valuation::BaseController
  def show
    authorize [:adm, :valuation, :setting], :show?

    @breadcrumbs = [
      { name: t("adm.valuation.menu.items.settings"), icon: "settings" }
    ]
  end
end
