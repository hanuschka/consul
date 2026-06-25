class Adm::DeficiencyReports::HomeController < Adm::DeficiencyReports::BaseController
  def show
    authorize DeficiencyReport, :index?, policy_class: Adm::DeficiencyReports::DeficiencyReportPolicy

    @team_members = DeficiencyReport::Officer.includes(user: :image).order(:id)

    @intro_text = Setting["adm.deficiency_reports.intro_text"].presence ||
                  I18n.t("adm.section_settings.intro_text_defaults.deficiency_reports", default: nil)
    @notice = if Setting["adm.deficiency_reports.notice_active"].present?
                Setting["adm.deficiency_reports.notice_message"]
              end
    @contact_persons = SectionContactPerson.for_section("deficiency_reports")
    @pagy_activities, @activities = pagy(
      SectionActivity.for_section("deficiency_reports")
        .for_trackables("DeficiencyReport", scoped_deficiency_reports.select(:id)),
      limit: 10,
      page_param: :activity_page
    )

    @stats = [
      { value: DeficiencyReport.count, label: t("adm.deficiency_reports.home.stats.total"), icon: "report" },
      { value: DeficiencyReport.where("created_at >= ?", 1.week.ago).count, label: t("adm.deficiency_reports.home.stats.new_this_week"), icon: "new_releases" },
      { value: DeficiencyReport.not_closed.count, label: t("adm.deficiency_reports.home.stats.open"), icon: "error" },
      { value: DeficiencyReport.closed.count, label: t("adm.deficiency_reports.home.stats.closed"), icon: "check_circle" }
    ]

    @breadcrumbs = [
      { name: t("adm.deficiency_reports.menu.items.home"), icon: "home" }
    ]
  end
end
