class Adm::Projekts::HomeController < Adm::Projekts::BaseController
  def show
    authorize Projekt, :index?, policy_class: Adm::Projekts::ProjektPolicy

    @team_members = scoped_team_members

    base_scope = ProjektsQuery.call(policy_scope([:adm, :projekts, Projekt]).reorder(updated_at: :desc), params)
    @pagy, @projekts = pagy(base_scope, limit: 10)

    @name_header_options = { sort: true, search: true }
    @start_date_header_options = { sort: true }
    @end_date_header_options = { sort: true }

    @section_setting = SectionSetting.for_section("projekts")
    @contact_persons = SectionContactPerson.for_section("projekts")
    visible_projekt_ids = policy_scope([:adm, :projekts, Projekt]).select(:id)
    @pagy_activities, @activities = pagy(
      SectionActivity.for_section("projekts")
        .where(trackable_type: "Projekt", trackable_id: visible_projekt_ids),
      limit: 10,
      page_param: :activity_page
    )

    @stats = [
      { value: Projekt.regular.count, label: t("adm.projekts.home.stats.total"), icon: "folder" },
      { value: Projekt.current.count, label: t("adm.projekts.home.stats.current"), icon: "play_circle" },
      { value: Projekt.expired.count, label: t("adm.projekts.home.stats.expired"), icon: "check_circle" },
      { value: Projekt.not_activated.count, label: t("adm.projekts.home.stats.draft"), icon: "edit_note" }
    ]

    @quick_links = [
      (if policy([:adm, :projekts, Projekt]).create?
         { label: t("adm.projekts.home.quick_links.new"), path: new_adm_projekts_projekt_path, primary: true }
       end),
      (if policy([:adm, :projekts, Projekt]).create? && Ai::Settings.ai_available?
         { label: t("adm.projekts.home.quick_links.import_projekt"), path: import_projekt_adm_projekts_projekts_path }
       end)
    ].compact

    @breadcrumbs = [
      { name: t("adm.projekts.menu.items.home"), icon: "home" }
    ]
  end

  private

    def scoped_team_members
      base = ProjektManager.includes(user: :image).order(:id)

      if current_user.administrator? || current_user.projekt_manager&.manage_all_projekts?
        base
      else
        shared_projekt_ids = current_user.projekt_manager
          &.projekt_manager_assignments
          &.pluck(:projekt_id) || []

        pm_ids = ProjektManagerAssignment.unscoped
          .where(projekt_id: shared_projekt_ids)
          .select(:projekt_manager_id)
          .distinct

        base.where(id: pm_ids)
      end
    end
end
