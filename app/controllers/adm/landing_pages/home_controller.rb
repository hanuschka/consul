class Adm::LandingPages::HomeController < Adm::LandingPages::BaseController
  def show
    authorize ::SiteCustomization::Page, :index?, policy_class: Adm::LandingPages::LandingPagePolicy

    @team_members = LandingPageManager.includes(user: :image).order(:id)
    @recent_items = policy_scope(::SiteCustomization::Page, policy_scope_class: Adm::LandingPages::LandingPagePolicy::Scope)
                      .order(updated_at: :desc).limit(10)

    @intro_text = Setting["adm.landing_pages.intro_text"].presence ||
                  I18n.t("adm.section_settings.intro_text_defaults.landing_pages", default: nil)
    @notice_active = Setting["adm.landing_pages.notice_active"].present?
    @notice_message = Setting["adm.landing_pages.notice_message"]
    @contact_persons = SectionContactPerson.for_section("landing_pages")
    @pagy_activities, @activities = pagy(SectionActivity.for_section("landing_pages"), limit: 10, page_param: :activity_page)

    @stats = [
      { value: ::SiteCustomization::Page.count, label: t("adm.landing_pages.home.stats.total"), icon: "web" },
      { value: ::SiteCustomization::Page.where(status: "published").count, label: t("adm.landing_pages.home.stats.published"), icon: "visibility" },
      { value: ::SiteCustomization::Page.where(status: "draft").count, label: t("adm.landing_pages.home.stats.draft"), icon: "edit_note" }
    ]

    @quick_links = [
      { label: t("adm.landing_pages.home.quick_links.new"), path: new_adm_landing_pages_landing_page_path, primary: true },
      { label: t("adm.landing_pages.home.quick_links.all"), path: adm_landing_pages_landing_pages_list_path }
    ]

    @breadcrumbs = [
      { name: t("adm.landing_pages.menu.items.home"), icon: "home" }
    ]
  end
end
