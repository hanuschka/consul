class Adm::Projekts::SettingsController < Adm::Projekts::BaseController
  def show
    authorize [:adm, :projekts, :setting], :show?

    @breadcrumbs = [
      { name: t("adm.projekts.menu.items.settings"), icon: "settings" }
    ]
  end
end
