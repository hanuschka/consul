class Adm::Projekts::LegislationDraftVersionsController < Adm::Projekts::BaseController

  before_action :set_projekt_phase
  before_action :set_process
  before_action :set_draft_version, only: %i[edit update destroy draft_text]

  def new
    @draft_version = @process.draft_versions.new
    authorize [:adm, :projekts, @draft_version], policy_class: Adm::Projekts::LegislationDraftVersionPolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def create
    @draft_version = @process.draft_versions.new(draft_version_params)
    authorize [:adm, :projekts, @draft_version], policy_class: Adm::Projekts::LegislationDraftVersionPolicy

    if @draft_version.save
      redirect_to legislation_process_draft_versions_adm_projekts_phase_path(@projekt_phase), notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.projekts.legislation_draft_versions.new.title"))
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize [:adm, :projekts, @draft_version], policy_class: Adm::Projekts::LegislationDraftVersionPolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def update
    authorize [:adm, :projekts, @draft_version], policy_class: Adm::Projekts::LegislationDraftVersionPolicy

    if @draft_version.update(draft_version_params)
      redirect_back fallback_location: legislation_process_draft_versions_adm_projekts_phase_path(@projekt_phase),
                    notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.projekts.legislation_draft_versions.edit.title"))
      render :edit, status: :unprocessable_entity
    end
  end

  def draft_text
    authorize [:adm, :projekts, @draft_version], policy_class: Adm::Projekts::LegislationDraftVersionPolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def destroy
    authorize [:adm, :projekts, @draft_version], policy_class: Adm::Projekts::LegislationDraftVersionPolicy

    @draft_version.destroy!
    redirect_to legislation_process_draft_versions_adm_projekts_phase_path(@projekt_phase), notice: t(".success")
  end

  private

    def set_projekt_phase
      @projekt_phase = ProjektPhase.find(params[:phase_id])
    end

    def set_process
      @process = @projekt_phase.legislation_process
    end

    def set_draft_version
      @draft_version = @process.draft_versions.find(params[:id])
    end

    def draft_version_params
      params.require(:legislation_draft_version).permit(
        :title, :changelog, :body,
        :status, :final_version
      )
    end

    def breadcrumbs_for_action(action_title)
      [
        { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
        { name: @projekt_phase.projekt.page.title, url: details_adm_projekts_projekt_path(@projekt_phase.projekt) },
        { name: @projekt_phase.title },
        { name: t("adm.projekts.phases.legislation_process_draft_versions.title"), url: legislation_process_draft_versions_adm_projekts_phase_path(@projekt_phase) },
        { name: action_title }
      ]
    end
end
