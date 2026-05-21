class Adm::Valuation::SettingsController < Adm::Valuation::BaseController
  before_action :authorize_settings, :load_breadcrumbs

  def show
  end

  def contact_persons
  end

  private

    def authorize_settings
      authorize [:adm, :valuation, :setting], :show?
    end

    def load_breadcrumbs
      @breadcrumbs = [{ name: t("adm.valuation.menu.items.settings"), icon: "settings" }]
    end
end
