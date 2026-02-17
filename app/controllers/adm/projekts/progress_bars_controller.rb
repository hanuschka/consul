class Adm::Projekts::ProgressBarsController < Adm::Projekts::BaseController
  before_action :set_projekt_phase
  before_action :set_progress_bar, only: %i[edit update destroy]

  def new
    @progress_bar = @projekt_phase.progress_bars.new
    authorize [:adm, :projekts, @progress_bar], policy_class: Adm::Projekts::ProgressBarPolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def create
    @progress_bar = @projekt_phase.progress_bars.new(progress_bar_params)
    authorize [:adm, :projekts, @progress_bar], policy_class: Adm::Projekts::ProgressBarPolicy

    if @progress_bar.save
      redirect_to progress_bars_adm_projekts_phase_path(@projekt_phase), notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.projekts.progress_bars.new.title"))
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize [:adm, :projekts, @progress_bar], policy_class: Adm::Projekts::ProgressBarPolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def update
    authorize [:adm, :projekts, @progress_bar], policy_class: Adm::Projekts::ProgressBarPolicy

    if @progress_bar.update(progress_bar_params)
      redirect_to progress_bars_adm_projekts_phase_path(@projekt_phase), notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.projekts.progress_bars.edit.title"))
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize [:adm, :projekts, @progress_bar], policy_class: Adm::Projekts::ProgressBarPolicy

    @progress_bar.destroy!
    redirect_to progress_bars_adm_projekts_phase_path(@projekt_phase), notice: t(".success")
  end

  private

    def set_projekt_phase
      @projekt_phase = ProjektPhase.find(params[:phase_id])
    end

    def set_progress_bar
      @progress_bar = @projekt_phase.progress_bars.find(params[:id])
    end

    def progress_bar_params
      params.require(:progress_bar).permit(:kind, :percentage, :title)
    end

    def breadcrumbs_for_action(action_title)
      [
        { name: t("adm.menu.items.projekts"), url: adm_projekts_root_path },
        { name: @projekt_phase.projekt.name, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
        { name: @projekt_phase.title },
        { name: t("adm.projekts.phases.progress_bars.title"), url: progress_bars_adm_projekts_phase_path(@projekt_phase) },
        { name: action_title }
      ]
    end
end
