class Adm::Officing::SettingsController < Adm::Officing::BaseController
  def show
    authorize [:adm, :officing, :setting], :show?

    @breadcrumbs = [
      { name: t("adm.officing.menu.items.settings"), icon: "settings" }
    ]
  end
end
