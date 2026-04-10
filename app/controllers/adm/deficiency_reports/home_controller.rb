class Adm::DeficiencyReports::HomeController < Adm::DeficiencyReports::BaseController
  def show
    authorize DeficiencyReport, :index?, policy_class: Adm::DeficiencyReports::DeficiencyReportPolicy

    @team_members = DeficiencyReport::Officer.includes(user: :image).order(:id)
    @recent_items = scoped_deficiency_reports
                      .includes(:status, :translations, :author, :category, :responsible, :feedback_form)
                      .order(updated_at: :desc).limit(10)

    @section_setting = SectionSetting.for_section("deficiency_reports")
    @contact_persons = SectionContactPerson.for_section("deficiency_reports")
    @activities = SectionActivity.for_section("deficiency_reports").limit(10)

    @stats = [
      { value: DeficiencyReport.count, label: t("adm.deficiency_reports.home.stats.total"), icon: "report" },
      { value: DeficiencyReport.where("created_at >= ?", 1.week.ago).count, label: t("adm.deficiency_reports.home.stats.new_this_week"), icon: "new_releases" },
      { value: DeficiencyReport.not_closed.count, label: t("adm.deficiency_reports.home.stats.open"), icon: "error" },
      { value: DeficiencyReport.closed.count, label: t("adm.deficiency_reports.home.stats.closed"), icon: "check_circle" }
    ]

    @quick_links = [
      { label: t("adm.deficiency_reports.home.quick_links.all"), path: adm_deficiency_reports_deficiency_reports_list_path }
    ]

    @breadcrumbs = [
      { name: t("adm.deficiency_reports.home.title"), icon: "home" }
    ]
  end
end
