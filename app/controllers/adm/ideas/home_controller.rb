class Adm::Ideas::HomeController < Adm::Ideas::BaseController
  def show
    authorize Idea, :index?, policy_class: Adm::Ideas::IdeaPolicy

    base_scope = policy_scope(Idea, policy_scope_class: Adm::Ideas::IdeaPolicy::Scope)
    base_scope = filter_assigned_ideas_only(base_scope)
    scope = Adm::IdeasQuery.call(base_scope, params)

    respond_to do |format|
      format.html do
        @pagy, @ideas = pagy(scope)
        @id_header_options         = { sort: true, search: true }
        @title_header_options      = { search: true }
        @created_at_header_options = { sort: true }
        @category_header_options   = { filter_options: category_filter_options }
        @officer_header_options    = { filter_options: officer_filter_options }

        @team_members = Idea::Officer.includes(user: :image).order(:id)

        @intro_text = Setting["adm.ideas.intro_text"].presence ||
                      I18n.t("adm.section_settings.intro_text_defaults.ideas", default: nil)
        @notice = Setting["adm.ideas.notice_active"].present? ? Setting["adm.ideas.notice_message"] : nil
        @contact_persons = SectionContactPerson.for_section("ideas")
        @pagy_activities, @activities = pagy(SectionActivity.for_section("ideas"), limit: 10, page_param: :activity_page)

        @stats = [
          { value: Idea.count, label: t("adm.ideas.home.stats.total"), icon: "lightbulb" },
          { value: Idea.where("created_at >= ?", 1.week.ago).count, label: t("adm.ideas.home.stats.new_this_week"), icon: "new_releases" },
          { value: Idea.active.count, label: t("adm.ideas.home.stats.active"), icon: "pending" },
          { value: Idea.archived.count, label: t("adm.ideas.home.stats.archived"), icon: "check_circle" }
        ]

        @breadcrumbs = [
          { name: t("adm.ideas.menu.items.home"), icon: "home" }
        ]
      end

      format.geojson do
        send_data GeoServices::MappablesGeojsonExporter.call(scope.preload(:category)),
                  filename: "ideas-#{Time.zone.today}.geojson",
                  type: "application/geo+json"
      end

      format.csv do
        send_data CsvServices::IdeasExporter.call(scope),
                  filename: "ideas-#{Time.zone.today}.csv",
                  type: "text/csv"
      end
    end
  end

  private

    def category_filter_options
      Idea::Category.all.map { |c| [c.id, c.name] }
    end

    def officer_filter_options
      Idea::Officer.all.map { |o| [o.id, o.name] }
    end
end
