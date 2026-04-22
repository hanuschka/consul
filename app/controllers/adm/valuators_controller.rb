module Adm
  class ValuatorsController < Adm::Valuation::BaseController
    include Admin::PendingRoleAssignable

    def index
      authorize [:adm, Valuator]
      @pagy, @valuators = pagy(policy_scope([:adm, Valuator]).order(id: :desc))

      @breadcrumbs = [
        { name: t("adm.valuators.index.title"), icon: "badge" }
      ]
    end

    def new
      authorize [:adm, Valuator], :index?

      @breadcrumbs = [
        { name: t("adm.valuators.index.title"), url: adm_valuators_path, icon: "badge" },
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
      check_pending_for_search
    end
  end
end
