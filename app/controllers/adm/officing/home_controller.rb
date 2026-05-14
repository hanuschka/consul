class Adm::Officing::HomeController < Adm::Officing::BaseController
  skip_after_action :verify_policy_scoped, only: :show

  def show
    authorize :base, policy_class: Adm::Officing::BasePolicy

    @team_members = OfficingManager.includes(user: :image).order(:id)

    if @officing_manager.present?
      @budgets = (
        @officing_manager.balloting_budgets +
        @officing_manager.selecting_budgets
      ).uniq

      @proposal_phases = @officing_manager.officing_proposal_phases
      @voting_phases = @officing_manager.officing_voting_phases
    else
      @budgets = []
      @proposal_phases = ProjektPhase::ProposalPhase.none
      @voting_phases = ProjektPhase::VotingPhase.none
    end

    @intro_text = Setting["adm.officing.intro_text"].presence ||
                  I18n.t("adm.section_settings.intro_text_defaults.officing", default: nil)
    @notice = Setting["adm.officing.notice_active"].present? ? Setting["adm.officing.notice_message"] : nil
    @contact_persons = SectionContactPerson.for_section("officing")
    @pagy_activities, @activities = pagy(SectionActivity.for_section("officing"), limit: 10, page_param: :activity_page)

    @stats = [
      { value: @budgets.size, label: t("adm.officing.home.stats.budgets"), icon: "account_balance_wallet" },
      { value: @proposal_phases.size, label: t("adm.officing.home.stats.proposals"), icon: "how_to_vote" },
      { value: @voting_phases.size, label: t("adm.officing.home.stats.polls"), icon: "ballot" }
    ]

    @breadcrumbs = [
      { name: t("adm.officing.menu.items.home"), icon: "home" }
    ]
  end
end
