module Adm
  class ProjektsController < Adm::BaseController
    def index
      authorize [:adm, Projekt]
      @projekts = policy_scope([:adm, Projekt])
      @breadcrumbs = [{ name: "Projekts", url: adm_projekts_path }]
    end

    def show
      @projekt = Projekt.find(params[:id])
      authorize [:adm, @projekt]
      @breadcrumbs = [
        { name: "Projekts", url: adm_projekts_path },
        { name: @projekt.name, url: adm_projekt_path(@projekt) }
      ]
    end
  end
end
