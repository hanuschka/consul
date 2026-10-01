class Adm::MunicipalPlans::HomeController < Adm::MunicipalPlans::BaseController
  def show
    authorize MunicipalPlan, :index?, policy_class: Adm::MunicipalPlans::MunicipalPlanPolicy

    @team_members = MunicipalPlan::Officer.includes(user: :image).order(:id)

    @intro_text = Setting["adm.municipal_plans.intro_text"].presence ||
                  I18n.t("adm.section_settings.intro_text_defaults.municipal_plans", default: nil)
    @notice = if Setting["adm.municipal_plans.notice_active"].present?
                Setting["adm.municipal_plans.notice_message"]
              end
    @contact_persons = SectionContactPerson.for_section("municipal_plans")
    @pagy_activities, @activities = pagy(
      SectionActivity.for_section("municipal_plans")
        .for_trackables("MunicipalPlan", scoped_plans.select(:id)),
      limit: 10,
      page_param: :activity_page
    )

    @stats = [
      { value: scoped_plans.count, label: t("adm.municipal_plans.home.stats.total"), icon: "assignment" },
      { value: scoped_plans.where("created_at >= ?", 1.week.ago).count, label: t("adm.municipal_plans.home.stats.new_this_week"), icon: "new_releases" },
      { value: scoped_plans.published.count, label: t("adm.municipal_plans.home.stats.published"), icon: "visibility" },
      { value: scoped_plans.archived.count, label: t("adm.municipal_plans.home.stats.archived"), icon: "inventory_2" }
    ]

    @breadcrumbs = [
      { name: t("adm.municipal_plans.menu.items.home"), icon: "home" }
    ]
  end

  private

    def scoped_plans
      policy_scope(MunicipalPlan, policy_scope_class: Adm::MunicipalPlans::MunicipalPlanPolicy::Scope).released_versions
    end
end
