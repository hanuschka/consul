class Adm::Projekts::ProjektEventsController < Adm::Projekts::BaseController
  include ImageAttributes

  before_action :set_projekt_phase
  before_action :set_projekt_event, only: %i[edit update destroy send_notifications]

  def new
    @projekt_event = @projekt_phase.projekt_events.new
    authorize [:adm, :projekts, @projekt_event], policy_class: Adm::Projekts::ProjektEventPolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def create
    @projekt_event = @projekt_phase.projekt_events.new(projekt_event_params)
    authorize [:adm, :projekts, @projekt_event], policy_class: Adm::Projekts::ProjektEventPolicy

    if @projekt_event.save
      redirect_to projekt_events_adm_projekts_phase_path(@projekt_phase), notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.projekts.projekt_events.new.title"))
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize [:adm, :projekts, @projekt_event], policy_class: Adm::Projekts::ProjektEventPolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def update
    authorize [:adm, :projekts, @projekt_event], policy_class: Adm::Projekts::ProjektEventPolicy

    if @projekt_event.update(projekt_event_params)
      redirect_to projekt_events_adm_projekts_phase_path(@projekt_phase), notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.projekts.projekt_events.edit.title"))
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize [:adm, :projekts, @projekt_event], policy_class: Adm::Projekts::ProjektEventPolicy

    @projekt_event.destroy!
    redirect_to projekt_events_adm_projekts_phase_path(@projekt_phase), notice: t(".success")
  end

  def send_notifications
    authorize [:adm, :projekts, @projekt_event], policy_class: Adm::Projekts::ProjektEventPolicy

    NotificationServices::NewProjektEventNotifier.call(@projekt_event.id)
    redirect_to projekt_events_adm_projekts_phase_path(@projekt_phase), notice: t(".success")
  end

  private

    def set_projekt_phase
      @projekt_phase = ProjektPhase.find(params[:phase_id])
    end

    def set_projekt_event
      @projekt_event = @projekt_phase.projekt_events.find(params[:id])
    end

    def projekt_event_params
      params.require(:projekt_event).permit(
        :title, :description, :location, :datetime, :end_datetime, :weblink,
        :open_ended, :language,
        :wheelchair_accessible, :accessible_toilet, :disabled_parking_nearby,
        :tactile_guidance_systems, :induction_loop_available,
        :assistance_dogs_welcome, :sign_language_interpreter,
        image_attributes: image_attributes
      )
    end

    def breadcrumbs_for_action(action_title)
      [
        { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
        { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
        { name: @projekt_phase.title },
        { name: t("adm.projekts.phases.projekt_events.title"), url: projekt_events_adm_projekts_phase_path(@projekt_phase) },
        { name: action_title }
      ]
    end
end
