class Adm::Projekts::HomeController < Adm::Projekts::BaseController
  def show
    authorize Projekt, :index?, policy_class: Adm::Projekts::ProjektPolicy

    flash_finished_copy

    @team_members = scoped_team_members

    @intro_text = Setting["adm.projekts.intro_text"].presence ||
                  I18n.t("adm.section_settings.intro_text_defaults.projekts", default: nil)
    @notice = Setting["adm.projekts.notice_active"].present? ? Setting["adm.projekts.notice_message"] : nil
    @contact_persons = SectionContactPerson.for_section("projekts")
    visible_projekt_ids = policy_scope([:adm, :projekts, Projekt]).select(:id)
    @pagy_activities, @activities = pagy(
      SectionActivity.for_section("projekts").for_trackables("Projekt", visible_projekt_ids),
      limit: 10,
      page_param: :activity_page
    )

    @stats = [
      { value: Projekt.regular.count, label: t("adm.projekts.home.stats.total"), icon: "folder" },
      { value: Projekt.current.count, label: t("adm.projekts.home.stats.current"), icon: "play_circle" },
      { value: Projekt.expired.count, label: t("adm.projekts.home.stats.expired"), icon: "check_circle" },
      { value: Projekt.not_activated.count, label: t("adm.projekts.home.stats.draft"), icon: "edit_note" }
    ]

    # Two entry points side by side: an empty projekt, and an import that first
    # asks where the projekt comes from. The import picker gates its own
    # sources on the AI flag — one of the three needs no AI — so the button
    # itself is never AI-gated.
    @can_create_projekt = policy([:adm, :projekts, Projekt]).create?
    @quick_links = [
      (if @can_create_projekt
         { label: t("adm.projekts.home.quick_links.new"), path: new_adm_projekts_projekt_path, primary: true }
       end)
    ].compact
    @import_picker_label = t("adm.projekts.home.quick_links.import")
    @ai_available = Ai::Settings.ai_available?

    @breadcrumbs = [
      { name: t("adm.projekts.menu.items.home"), icon: "home" }
    ]
  end

  private

    # The copy poller sends the admin here once a copy reaches a terminal state,
    # so this is where its outcome gets announced. copy_status now only ever
    # describes a local copy: an import from another instance is a ProjektImport
    # and reports through the import screens instead.
    def flash_finished_copy
      copy = policy_scope([:adm, :projekts, Projekt]).find_by(id: params[:finished_copy])
      return if copy.blank? || copy.copy_status.blank?
      return if copy.copy_in_progress?

      if copy.copy_unfinished?
        flash.now[:alert] = t("adm.projekts.projekts.copy.failed_notice", name: copy.title)
      else
        flash.now[:notice] = t("adm.projekts.projekts.copy.finished", name: copy.title)
      end
    end

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
