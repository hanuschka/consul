module Adm
  class DeficiencyReportManagersController < Adm::BaseController
    include Admin::PendingRoleAssignable

    def index
      authorize [:adm, DeficiencyReportManager]
      @pagy, @deficiency_report_managers = pagy(
        policy_scope([:adm, DeficiencyReportManager]).order(id: :desc)
      )

      @breadcrumbs = [
        { name: t("adm.menu.items.profiles"), icon: "3p" },
        { name: t("adm.menu.items.profiles_subitems.deficiency_report_managers") }
      ]
    end

    def new
      authorize [:adm, DeficiencyReportManager], :index?

      @breadcrumbs = [
        { name: t("adm.menu.items.profiles"), icon: "3p" },
        { name: t("adm.menu.items.profiles_subitems.deficiency_report_managers"),
          url: adm_deficiency_report_managers_path },
        { name: t(".title") }
      ]
    end

    def destroy
      authorize [:adm, DeficiencyReportManager], :index?
      @deficiency_report_manager = DeficiencyReportManager.find(params[:id])
      @deficiency_report_manager.destroy!
    end

    def search
      authorize [:adm, DeficiencyReportManager], :index?
      params[:role] = "deficiency_report_manager"
      @users = User.search(params[:search]).where.missing(:deficiency_report_manager).limit(4)
      check_pending_for_search
    end
  end
end
