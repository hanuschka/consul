class Adm::Projekts::HomeController < Adm::Projekts::BaseController
  def show
    authorize Projekt, :index?, policy_class: Adm::Projekts::ProjektPolicy

    @team_members = scoped_team_members
    @recent_items = policy_scope([:adm, :projekts, Projekt])
                      .includes(:parent, :landing_page, image_attachment: :blob, images_attachments: :blob, page: :translations)
                      .order(updated_at: :desc).limit(10)

    @section_setting = SectionSetting.for_section("projekts")
    @contact_persons = SectionContactPerson.for_section("projekts")
    @activities = SectionActivity.for_section("projekts").limit(10)

    @stats = [
      { value: Projekt.regular.count, label: t("adm.projekts.home.stats.total"), icon: "folder" },
      { value: Projekt.current.count, label: t("adm.projekts.home.stats.current"), icon: "play_circle" },
      { value: Projekt.expired.count, label: t("adm.projekts.home.stats.expired"), icon: "check_circle" },
      { value: Projekt.not_activated.count, label: t("adm.projekts.home.stats.draft"), icon: "edit_note" }
    ]

    @quick_links = [
      { label: t("adm.projekts.home.quick_links.new"), path: new_adm_projekts_projekt_path, primary: true },
      { label: t("adm.projekts.home.quick_links.all"), path: adm_projekts_projekts_list_path },
      { label: t("adm.projekts.home.quick_links.current"), path: adm_projekts_projekts_list_path(filter: "current") }
    ]

    @breadcrumbs = [
      { name: t("adm.projekts.home.title"), icon: "home" }
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

        pm_ids = ProjektManagerAssignment
          .where(projekt_id: shared_projekt_ids)
          .select(:projekt_manager_id)
          .distinct

        base.where(id: pm_ids)
      end
    end
end
