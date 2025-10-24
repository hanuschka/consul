module Adm
  class ProjektsController < Adm::BaseController
    def index
      authorize [:adm, Projekt]
      @pagy, @projekts = pagy(policy_scope([:adm, Projekt]), limit: 10)
      @breadcrumbs = [
        { name: t("adm.menu.items.home"), url: adm_root_path },
        { name: t("adm.menu.items.projekts") }
      ]
    end

    def show
      @projekt = Projekt.find(params[:id])
      authorize [:adm, @projekt]
      @breadcrumbs = [
        { name: t("adm.menu.items.home"), url: adm_root_path },
        { name: t("adm.menu.items.projekts"), url: adm_projekts_path },
        { name: @projekt.name }
      ]
    end
  end
end
