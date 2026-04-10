class Adm::Ideas::HomeController < Adm::Ideas::BaseController
  def show
    authorize Idea, :index?, policy_class: Adm::Ideas::IdeaPolicy

    @team_members = Idea::Officer.includes(user: :image).order(:id)
    @recent_items = scoped_ideas.includes(:translations).order(updated_at: :desc).limit(10)

    @section_setting = SectionSetting.for_section("ideas")
    @contact_persons = SectionContactPerson.for_section("ideas")
    @activities = SectionActivity.for_section("ideas").limit(10)

    @stats = [
      { value: Idea.count, label: t("adm.ideas.home.stats.total"), icon: "lightbulb" },
      { value: Idea.where("created_at >= ?", 1.week.ago).count, label: t("adm.ideas.home.stats.new_this_week"), icon: "new_releases" },
      { value: Idea.active.count, label: t("adm.ideas.home.stats.active"), icon: "pending" },
      { value: Idea.archived.count, label: t("adm.ideas.home.stats.archived"), icon: "check_circle" }
    ]

    @quick_links = [
      { label: t("adm.ideas.home.quick_links.all"), path: adm_ideas_ideas_list_path, primary: true },
      { label: t("adm.ideas.home.quick_links.active"), path: adm_ideas_ideas_list_path(filter: "active") },
      { label: t("adm.ideas.home.quick_links.pending"), path: adm_ideas_ideas_list_path(filter: "pending") }
    ]

    @breadcrumbs = [
      { name: t("adm.ideas.home.title"), icon: "home" }
    ]
  end
end
