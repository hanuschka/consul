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

    @quick_links = [
      (if policy([:adm, :projekts, Projekt]).create?
         { label: t("adm.projekts.home.quick_links.new"), path: new_adm_projekts_projekt_path, primary: true }
       end),
      (if policy([:adm, :projekts, Projekt]).create?
         { label: t("adm.projekts.home.quick_links.imports"),
           path: adm_projekts_imports_path,
           ai_gated: true,
           description: t("adm.projekts.imports.index.new_button_description") }
       end)
    ].compact

    @breadcrumbs = [
      { name: t("adm.projekts.menu.items.home"), icon: "home" }
    ]
  end

  private

    # The copy poller sends the admin here once a copy reaches a terminal state,
    # so this is where its outcome gets announced. A cross-instance import
    # shares that column and that poller, and is told apart by having no local
    # source projekt to point back at.
    def flash_finished_copy
      copy = policy_scope([:adm, :projekts, Projekt]).find_by(id: params[:finished_copy])
      return if copy.blank? || copy.copy_status.blank?
      return if copy.copy_in_progress?

      scope = copy.copied_from_projekt_id.present? ? "copy" : "instance_import"

      if copy.copy_unfinished?
        flash.now[:alert] = t("adm.projekts.projekts.#{scope}.failed_notice", name: copy.title)
      else
        flash.now[:notice] = t("adm.projekts.projekts.#{scope}.finished", name: copy.title)
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
