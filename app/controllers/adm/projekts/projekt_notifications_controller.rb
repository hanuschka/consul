class Adm::Projekts::ProjektNotificationsController < Adm::Projekts::BaseController
  before_action :set_projekt_phase
  before_action :set_projekt_notification, only: %i[edit update destroy]

  def new
    @projekt_notification = @projekt_phase.projekt_notifications.new
    authorize [:adm, :projekts, @projekt_notification], policy_class: Adm::Projekts::ProjektNotificationPolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def create
    @projekt_notification = @projekt_phase.projekt_notifications.new(projekt_notification_params)
    authorize [:adm, :projekts, @projekt_notification], policy_class: Adm::Projekts::ProjektNotificationPolicy

    if @projekt_notification.save
      NotificationServices::NewProjektNotificationNotifier.call(@projekt_notification.id)
      redirect_to projekt_notifications_adm_projekts_phase_path(@projekt_phase), notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.projekts.projekt_notifications.new.title"))
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize [:adm, :projekts, @projekt_notification], policy_class: Adm::Projekts::ProjektNotificationPolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def update
    authorize [:adm, :projekts, @projekt_notification], policy_class: Adm::Projekts::ProjektNotificationPolicy

    if @projekt_notification.update(projekt_notification_params)
      redirect_to projekt_notifications_adm_projekts_phase_path(@projekt_phase), notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.projekts.projekt_notifications.edit.title"))
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize [:adm, :projekts, @projekt_notification], policy_class: Adm::Projekts::ProjektNotificationPolicy

    @projekt_notification.destroy!
    redirect_to projekt_notifications_adm_projekts_phase_path(@projekt_phase), notice: t(".success")
  end

  private

    def set_projekt_phase
      @projekt_phase = ProjektPhase.find(params[:phase_id])
    end

    def set_projekt_notification
      @projekt_notification = @projekt_phase.projekt_notifications.find(params[:id])
    end

    def projekt_notification_params
      params.require(:projekt_notification).permit(:title, :body)
    end

    def breadcrumbs_for_action(action_title)
      [
        { name: t("adm.menu.items.projekts"), url: adm_projekts_root_path },
        { name: @projekt_phase.projekt.name, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
        { name: @projekt_phase.title },
        { name: t("adm.projekts.phases.projekt_notifications.title"), url: projekt_notifications_adm_projekts_phase_path(@projekt_phase) },
        { name: action_title }
      ]
    end
end
