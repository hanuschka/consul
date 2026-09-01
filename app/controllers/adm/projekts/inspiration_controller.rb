class Adm::Projekts::InspirationController < Adm::Projekts::BaseController
  before_action :authorize_inspiration, :load_breadcrumbs

  def show
    @embed_url = "#{Dt.url}/?embedded_full=true" if Dt.url.present?
  end

  private

    def authorize_inspiration
      authorize [:adm, :projekts, :inspiration], :show?
    end

    def load_breadcrumbs
      @breadcrumbs = [{ name: t("adm.projekts.menu.items.inspiration"), icon: "travel_explore" }]
    end
end
