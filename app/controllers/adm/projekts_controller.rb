module Adm
  class ProjektsController < Adm::BaseController
    def index
      authorize [:adm, Projekt]
      @projekts = policy_scope([:adm, Projekt])
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
