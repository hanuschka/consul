class Adm::Projekts::ProjektLivestreamsController < Adm::Projekts::BaseController
  before_action :set_projekt_phase
  before_action :set_projekt_livestream, only: %i[show edit update destroy send_notifications]

  def show
    authorize [:adm, :projekts, @projekt_livestream], :update?, policy_class: Adm::Projekts::ProjektLivestreamPolicy

    @breadcrumbs = [
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
      { name: @projekt_phase.projekt.name, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t("adm.projekts.phases.projekt_livestreams.title"), url: projekt_livestreams_adm_projekts_phase_path(@projekt_phase) },
      { name: @projekt_livestream.title }
    ]
  end

  def new
    @projekt_livestream = @projekt_phase.projekt_livestreams.new
    authorize [:adm, :projekts, @projekt_livestream], policy_class: Adm::Projekts::ProjektLivestreamPolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def create
    @projekt_livestream = @projekt_phase.projekt_livestreams.new(projekt_livestream_params)
    authorize [:adm, :projekts, @projekt_livestream], policy_class: Adm::Projekts::ProjektLivestreamPolicy

    if @projekt_livestream.save
      redirect_to projekt_livestreams_adm_projekts_phase_path(@projekt_phase), notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.projekts.projekt_livestreams.new.title"))
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize [:adm, :projekts, @projekt_livestream], policy_class: Adm::Projekts::ProjektLivestreamPolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def update
    authorize [:adm, :projekts, @projekt_livestream], policy_class: Adm::Projekts::ProjektLivestreamPolicy

    if @projekt_livestream.update(projekt_livestream_params)
      redirect_to projekt_livestreams_adm_projekts_phase_path(@projekt_phase), notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.projekts.projekt_livestreams.edit.title"))
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize [:adm, :projekts, @projekt_livestream], policy_class: Adm::Projekts::ProjektLivestreamPolicy

    @projekt_livestream.destroy!
    redirect_to projekt_livestreams_adm_projekts_phase_path(@projekt_phase), notice: t(".success")
  end

  def send_notifications
    authorize [:adm, :projekts, @projekt_livestream], :update?, policy_class: Adm::Projekts::ProjektLivestreamPolicy

    NotificationServices::NewProjektLivestreamNotifier.call(@projekt_livestream.id)
    redirect_to projekt_livestreams_adm_projekts_phase_path(@projekt_phase), notice: t(".success")
  end

  private

    def set_projekt_phase
      @projekt_phase = ProjektPhase.find(params[:phase_id])
    end

    def set_projekt_livestream
      @projekt_livestream = @projekt_phase.projekt_livestreams.find(params[:id])
    end

    def projekt_livestream_params
      params.require(:projekt_livestream).permit(:url, :title, :starts_at, :description)
    end

    def breadcrumbs_for_action(action_title)
      [
        { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
        { name: @projekt_phase.projekt.name, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
        { name: @projekt_phase.title },
        { name: t("adm.projekts.phases.projekt_livestreams.title"), url: projekt_livestreams_adm_projekts_phase_path(@projekt_phase) },
        { name: action_title }
      ]
    end
end
