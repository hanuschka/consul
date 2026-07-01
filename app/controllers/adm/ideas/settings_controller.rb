class Adm::Ideas::SettingsController < Adm::Ideas::BaseController
  before_action :authorize_settings, :load_breadcrumbs

  def show
  end

  def dashboard
  end

  def contact_persons
  end

  private

    def authorize_settings
      authorize [:adm, :ideas, :setting], :show?
    end

    def load_breadcrumbs
      @breadcrumbs = [{ name: t("adm.ideas.settings.title"), icon: "settings" }]
    end
end
