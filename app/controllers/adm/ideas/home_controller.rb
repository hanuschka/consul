class Adm::Ideas::HomeController < Adm::Ideas::BaseController
  def show
    authorize Idea, :index?, policy_class: Adm::Ideas::IdeaPolicy

    @team_members = Idea::Officer.includes(user: :image).order(:id)
    @recent_items = scoped_ideas.includes(:translations, :author, :category, :officer).order(updated_at: :desc).limit(10)

    @intro_text = Setting["adm.ideas.intro_text"].presence ||
                  I18n.t("adm.section_settings.intro_text_defaults.ideas", default: nil)
    @notice_active = Setting["adm.ideas.notice_active"].present?
    @notice_message = Setting["adm.ideas.notice_message"]
    @contact_persons = SectionContactPerson.for_section("ideas")
    @pagy_activities, @activities = pagy(SectionActivity.for_section("ideas"), limit: 10, page_param: :activity_page)

    @stats = [
      { value: Idea.count, label: t("adm.ideas.home.stats.total"), icon: "lightbulb" },
      { value: Idea.where("created_at >= ?", 1.week.ago).count, label: t("adm.ideas.home.stats.new_this_week"), icon: "new_releases" },
      { value: Idea.active.count, label: t("adm.ideas.home.stats.active"), icon: "pending" },
      { value: Idea.archived.count, label: t("adm.ideas.home.stats.archived"), icon: "check_circle" }
    ]

    @quick_links = [
      { label: t("adm.ideas.home.quick_links.all"), path: adm_ideas_ideas_list_path }
    ]

    @breadcrumbs = [
      { name: t("adm.ideas.menu.items.home"), icon: "home" }
    ]
  end
end
