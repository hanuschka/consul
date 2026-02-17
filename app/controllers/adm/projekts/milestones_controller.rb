class Adm::Projekts::MilestonesController < Adm::Projekts::BaseController
  include ImageAttributes

  before_action :set_projekt_phase
  before_action :set_milestone, only: %i[edit update destroy]

  def new
    @milestone = @projekt_phase.milestones.new
    authorize [:adm, :projekts, @milestone], policy_class: Adm::Projekts::MilestonePolicy

    @statuses = Milestone::Status.all
    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def create
    @milestone = @projekt_phase.milestones.new(milestone_params)
    authorize [:adm, :projekts, @milestone], policy_class: Adm::Projekts::MilestonePolicy

    if @milestone.save
      NotificationServices::NewProjektMilestoneNotifier.call(@milestone.id)
      redirect_to milestones_adm_projekts_phase_path(@projekt_phase), notice: t(".success")
    else
      @statuses = Milestone::Status.all
      @breadcrumbs = breadcrumbs_for_action(t("adm.projekts.milestones.new.title"))
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize [:adm, :projekts, @milestone], policy_class: Adm::Projekts::MilestonePolicy

    @statuses = Milestone::Status.all
    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def update
    authorize [:adm, :projekts, @milestone], policy_class: Adm::Projekts::MilestonePolicy

    if @milestone.update(milestone_params)
      redirect_to milestones_adm_projekts_phase_path(@projekt_phase), notice: t(".success")
    else
      @statuses = Milestone::Status.all
      @breadcrumbs = breadcrumbs_for_action(t("adm.projekts.milestones.edit.title"))
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize [:adm, :projekts, @milestone], policy_class: Adm::Projekts::MilestonePolicy

    @milestone.destroy!
    redirect_to milestones_adm_projekts_phase_path(@projekt_phase), notice: t(".success")
  end

  private

    def set_projekt_phase
      @projekt_phase = ProjektPhase.find(params[:phase_id])
    end

    def set_milestone
      @milestone = @projekt_phase.milestones.find(params[:id])
    end

    def milestone_params
      params.require(:milestone).permit(
        :publication_date, :status_id, :description, :custom_date,
        image_attributes: image_attributes
      )
    end

    def breadcrumbs_for_action(action_title)
      [
        { name: t("adm.menu.items.projekts"), url: adm_projekts_root_path },
        { name: @projekt_phase.projekt.name, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
        { name: @projekt_phase.title },
        { name: t("adm.projekts.phases.milestones.title"), url: milestones_adm_projekts_phase_path(@projekt_phase) },
        { name: action_title }
      ]
    end
end
