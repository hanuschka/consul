class Adm::LandingPages::HomeController < Adm::LandingPages::BaseController
  def show
    authorize ::SiteCustomization::Page, :index?, policy_class: Adm::LandingPages::LandingPagePolicy

    @team_members = LandingPageManager.includes(user: :image).order(:id)
    @landing_pages = policy_scope(::SiteCustomization::Page,
                                  policy_scope_class: Adm::LandingPages::LandingPagePolicy::Scope).order(:landing_nav_position)

    @intro_text = Setting["adm.landing_pages.intro_text"].presence ||
                  I18n.t("adm.section_settings.intro_text_defaults.landing_pages", default: nil)
    @notice = if Setting["adm.landing_pages.notice_active"].present?
                Setting["adm.landing_pages.notice_message"]
              end
    @contact_persons = SectionContactPerson.for_section("landing_pages")
    @pagy_activities, @activities = pagy(SectionActivity.for_section("landing_pages"), limit: 10, page_param: :activity_page)

    @stats = [
      { value: ::SiteCustomization::Page.count, label: t("adm.landing_pages.home.stats.total"), icon: "web" },
      { value: ::SiteCustomization::Page.where(status: "published").count, label: t("adm.landing_pages.home.stats.published"), icon: "visibility" },
      { value: ::SiteCustomization::Page.where(status: "draft").count, label: t("adm.landing_pages.home.stats.draft"), icon: "edit_note" }
    ]

    @quick_links = [
      { label: t("adm.landing_pages.home.quick_links.new"), path: new_adm_landing_pages_landing_page_path, primary: true }
    ]

    @breadcrumbs = [
      { name: t("adm.landing_pages.menu.items.home"), icon: "home" }
    ]
  end
end
