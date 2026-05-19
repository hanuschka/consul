class Adm::Officing::SettingsController < Adm::Officing::BaseController
  before_action :authorize_settings, :load_breadcrumbs

  def show
  end

  def contact_persons
  end

  private

    def authorize_settings
      authorize [:adm, :officing, :setting], :show?
    end

    def load_breadcrumbs
      @breadcrumbs = [{ name: t("adm.officing.menu.items.settings"), icon: "settings" }]
    end
end
