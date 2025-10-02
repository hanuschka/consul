module Adm
  class ProjektsController < Adm::BaseController
    def index
      authorize [:adm, Projekt]
      @projekts = policy_scope([:adm, Projekt])
    end

    def show
      @projekt = Projekt.find(params[:id])
      authorize [:adm, @projekt]
    end
  end
end
