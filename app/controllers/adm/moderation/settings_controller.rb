class Adm::Moderation::SettingsController < Adm::Moderation::BaseController
  before_action :authorize_settings, :load_breadcrumbs

  def show
  end

  def contact_persons
  end

  private

    def authorize_settings
      authorize [:adm, :moderation, :setting], :show?
    end

    def load_breadcrumbs
      @breadcrumbs = [{ name: t("adm.moderation.menu.items.settings"), icon: "settings" }]
    end
end
