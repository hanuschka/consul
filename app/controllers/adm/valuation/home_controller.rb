class Adm::Valuation::HomeController < Adm::Valuation::BaseController
  def show
    authorize Budget::Investment, :index?, policy_class: Adm::Valuation::BudgetInvestmentPolicy

    @team_members = Valuator.includes(user: :image).order(:id)
    @recent_items = policy_scope(Budget::Investment, policy_scope_class: Adm::Valuation::BudgetInvestmentPolicy::Scope)
                      .includes(:budget, :translations)
                      .order(updated_at: :desc).limit(10)

    @intro_text = Setting["adm.valuation.intro_text"].presence ||
                  I18n.t("adm.section_settings.intro_text_defaults.valuation", default: nil)
    @notice_active = Setting["adm.valuation.notice_active"].present?
    @notice_message = Setting["adm.valuation.notice_message"]
    @contact_persons = SectionContactPerson.for_section("valuation")
    @pagy_activities, @activities = pagy(SectionActivity.for_section("valuation"), limit: 10, page_param: :activity_page)

    @stats = [
      { value: Budget::Investment.count, label: t("adm.valuation.home.stats.total"), icon: "account_balance" },
      { value: Budget::Investment.valuation_open.where(valuator_assignments_count: 0, valuator_group_assignments_count: 0).count, label: t("adm.valuation.home.stats.not_valued"), icon: "hourglass_empty" },
      { value: Budget::Investment.valuating.count, label: t("adm.valuation.home.stats.in_valuation"), icon: "rate_review" },
      { value: Budget::Investment.valuation_finished.count, label: t("adm.valuation.home.stats.valued"), icon: "check_circle" }
    ]

    @quick_links = [
      { label: t("adm.valuation.home.quick_links.all"), path: adm_valuation_investments_path }
    ]

    @breadcrumbs = [
      { name: t("adm.valuation.menu.items.home"), icon: "home" }
    ]
  end
end
