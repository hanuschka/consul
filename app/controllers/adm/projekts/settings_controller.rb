class Adm::Projekts::SettingsController < Adm::Projekts::BaseController
  before_action :authorize_settings, :load_breadcrumbs

  def show
  end

  def contact_persons
  end

  private

    def authorize_settings
      authorize [:adm, :projekts, :setting], :show?
    end

    def load_breadcrumbs
      @breadcrumbs = [{ name: t("adm.projekts.menu.items.settings"), icon: "settings" }]
    end
end
