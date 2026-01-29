module Adm
  class ValuatorsController < Adm::BaseController
    def index
      authorize [:adm, Valuator]
      @pagy, @valuators = pagy(policy_scope([:adm, Valuator]).order(id: :desc))

      @breadcrumbs = [
        { name: t("adm.menu.items.profiles") },
        { name: t("adm.menu.items.profiles_subitems.valuators") }
      ]
    end

    def new
      authorize [:adm, Valuator], :index?

      @breadcrumbs = [
        { name: t("adm.menu.items.profiles") },
        { name: t("adm.menu.items.profiles_subitems.valuators"), url: adm_valuators_path },
        { name: t(".title") }
      ]
    end

    def destroy
      authorize [:adm, Valuator], :index?
      @valuator = Valuator.find(params[:id])
      @valuator.destroy!
    end

    def search
      authorize [:adm, Valuator], :index?
      params[:role] = "valuator"
      @users = User.search(params[:search]).where.missing(:valuator).limit(4)
    end
  end
end
