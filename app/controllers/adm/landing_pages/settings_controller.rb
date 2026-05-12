class Adm::LandingPages::SettingsController < Adm::LandingPages::BaseController
  def show
    authorize [:adm, :landing_pages, :setting], :show?

    @breadcrumbs = [
      { name: t("adm.landing_pages.menu.items.settings"), icon: "settings" }
    ]
  end
end
