class Adm::LandingPages::SettingsController < Adm::LandingPages::BaseController
  before_action :authorize_settings, :load_breadcrumbs

  def show
  end

  def contact_persons
  end

  private

    def authorize_settings
      authorize [:adm, :landing_pages, :setting], :show?
    end

    def load_breadcrumbs
      @breadcrumbs = [{ name: t("adm.landing_pages.menu.items.settings"), icon: "settings" }]
    end
end
