class Adm::Offers::SettingsController < Adm::Offers::BaseController
  def show
    authorize [:adm, :offers, :setting], :show?

    @breadcrumbs = [{ name: t("adm.offers.settings.title"), icon: "settings" }]
  end
end
