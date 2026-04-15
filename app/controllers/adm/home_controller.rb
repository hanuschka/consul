module Adm
  class HomeController < Adm::BaseController
    def show
      authorize [:adm, :home]
      @breadcrumbs = [
        { name: t("adm.menu.items.home"), icon: "home" }
      ]

      # Users
      @users_total        = User.active.count
      @users_new_week     = User.active.where("users.created_at >= ?", 7.days.ago).count

      # Deficiency Reports
      @reports_total      = DeficiencyReport.not_archived.count
      @reports_open       = DeficiencyReport.not_closed.not_archived.count
      @reports_unassigned = DeficiencyReport.not_assigned.not_archived.count

      # Projects
      @projects_total   = Projekt.regular.count
      @projects_current = Projekt.current.regular.count
      @projects_expired = Projekt.expired.regular.count
    end
  end
end
