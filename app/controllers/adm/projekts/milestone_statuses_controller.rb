class Adm::Projekts::MilestoneStatusesController < Adm::Projekts::BaseController
  before_action :set_status, only: %i[edit update destroy]

  def index
    authorize [:adm, :projekts, Milestone::Status], :index?, policy_class: Adm::Projekts::MilestoneStatusPolicy

    @statuses = policy_scope(Milestone::Status, policy_scope_class: Adm::Projekts::MilestoneStatusPolicy::Scope)

    @breadcrumbs = [
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
      { name: t(".title") }
    ]
  end

  def new
    @status = Milestone::Status.new
    authorize [:adm, :projekts, @status], policy_class: Adm::Projekts::MilestoneStatusPolicy

    @breadcrumbs = [
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
      { name: t("adm.projekts.milestone_statuses.index.title"), url: adm_projekts_milestone_statuses_path },
      { name: t(".title") }
    ]
  end

  def create
    @status = Milestone::Status.new(status_params)
    authorize [:adm, :projekts, @status], policy_class: Adm::Projekts::MilestoneStatusPolicy

    if @status.save
      redirect_to adm_projekts_milestone_statuses_path, notice: t(".success")
    else
      @breadcrumbs = [
        { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
        { name: t("adm.projekts.milestone_statuses.index.title"), url: adm_projekts_milestone_statuses_path },
        { name: t("adm.projekts.milestone_statuses.new.title") }
      ]
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize [:adm, :projekts, @status], policy_class: Adm::Projekts::MilestoneStatusPolicy

    @breadcrumbs = [
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
      { name: t("adm.projekts.milestone_statuses.index.title"), url: adm_projekts_milestone_statuses_path },
      { name: t(".title") }
    ]
  end

  def update
    authorize [:adm, :projekts, @status], policy_class: Adm::Projekts::MilestoneStatusPolicy

    if @status.update(status_params)
      redirect_to adm_projekts_milestone_statuses_path, notice: t(".success")
    else
      @breadcrumbs = [
        { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
        { name: t("adm.projekts.milestone_statuses.index.title"), url: adm_projekts_milestone_statuses_path },
        { name: t("adm.projekts.milestone_statuses.edit.title") }
      ]
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize [:adm, :projekts, @status], policy_class: Adm::Projekts::MilestoneStatusPolicy

    @status.destroy!
    redirect_to adm_projekts_milestone_statuses_path, notice: t(".success")
  end

  private

    def set_status
      @status = Milestone::Status.find(params[:id])
    end

    def status_params
      params.require(:milestone_status).permit(:name, :description)
    end
end
