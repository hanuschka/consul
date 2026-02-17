class Adm::Projekts::ProjektArgumentsController < Adm::Projekts::BaseController
  include ImageAttributes

  before_action :set_projekt_phase
  before_action :set_projekt_argument, only: %i[edit update destroy]

  def new
    @projekt_argument = @projekt_phase.projekt_arguments.new
    authorize [:adm, :projekts, @projekt_argument], policy_class: Adm::Projekts::ProjektArgumentPolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def create
    @projekt_argument = @projekt_phase.projekt_arguments.new(projekt_argument_params)
    authorize [:adm, :projekts, @projekt_argument], policy_class: Adm::Projekts::ProjektArgumentPolicy

    if @projekt_argument.save
      redirect_to projekt_arguments_adm_projekts_phase_path(@projekt_phase), notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.projekts.projekt_arguments.new.title"))
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize [:adm, :projekts, @projekt_argument], policy_class: Adm::Projekts::ProjektArgumentPolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def update
    authorize [:adm, :projekts, @projekt_argument], policy_class: Adm::Projekts::ProjektArgumentPolicy

    if @projekt_argument.update(projekt_argument_params)
      redirect_to projekt_arguments_adm_projekts_phase_path(@projekt_phase), notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.projekts.projekt_arguments.edit.title"))
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize [:adm, :projekts, @projekt_argument], policy_class: Adm::Projekts::ProjektArgumentPolicy

    @projekt_argument.destroy!
    redirect_to projekt_arguments_adm_projekts_phase_path(@projekt_phase), notice: t(".success")
  end

  def send_notifications
    authorize @projekt_phase, :update?, policy_class: Adm::Projekts::ProjektPhasePolicy

    NotificationServices::ProjektArgumentsNotifier.call(@projekt_phase.id)
    redirect_to projekt_arguments_adm_projekts_phase_path(@projekt_phase), notice: t(".success")
  end

  private

    def set_projekt_phase
      @projekt_phase = ProjektPhase.find(params[:phase_id])
    end

    def set_projekt_argument
      @projekt_argument = @projekt_phase.projekt_arguments.find(params[:id])
    end

    def projekt_argument_params
      params.require(:projekt_argument).permit(:name, :party, :pro, :position, :note, image_attributes: image_attributes)
    end

    def breadcrumbs_for_action(action_title)
      [
        { name: t("adm.menu.items.projekts"), url: adm_projekts_root_path },
        { name: @projekt_phase.projekt.name, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
        { name: @projekt_phase.title },
        { name: t("adm.projekts.phases.projekt_arguments.title"), url: projekt_arguments_adm_projekts_phase_path(@projekt_phase) },
        { name: action_title }
      ]
    end
end
