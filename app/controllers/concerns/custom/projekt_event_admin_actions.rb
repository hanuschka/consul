module ProjektEventAdminActions
  extend ActiveSupport::Concern

  included do
    include ImageAttributes

    before_action :set_namespace
    before_action :set_projekt_event, :set_projekt_phase, only: [:edit, :update, :destroy, :send_notifications]
  end

  def edit
    authorize!(:edit, @projekt_event)

    render "custom/admin/projekt_events/edit"
  end

  def create
    @projekt_event = ProjektEvent.new(projekt_event_params)
    authorize!(:create, @projekt_event)

    @projekt_event.save!
    redirect_to polymorphic_path([@namespace, @projekt_event.projekt_phase], action: :projekt_events), notice: t("admin.settings.flash.updated")
  end

  def update
    authorize!(:update, @projekt_event)

    @projekt_event.update!(projekt_event_params)
    redirect_to polymorphic_path([@namespace, @projekt_phase], action: :projekt_events), notice: t("admin.settings.flash.updated")
  end

  def destroy
    authorize!(:destroy, @projekt_event)
    @projekt_event.destroy!

    redirect_to polymorphic_path([@namespace, @projekt_phase], action: :projekt_events)
  end

  def send_notifications
    authorize!(:send_notifications, @projekt_event)
    NotificationServices::NewProjektEventNotifier.call(@projekt_event.id)
    redirect_to polymorphic_path([@namespace, @projekt_phase], action: :projekt_events),
      notice: t("custom.admin.projekts.edit.projekt_events.notifications_sent_notice")
  end

  private

    def projekt_event_params
      params
        .require(:projekt_event)
        .permit(
          :projekt_phase_id, :title, :description, :location, :datetime, :end_datetime, :weblink,
          :open_ended,
          image_attributes: image_attributes
        )
    end

    def set_projekt_event
      @projekt_event = ProjektEvent.find_by(id: params[:id])
    end

    def set_projekt_phase
      @projekt_phase = @projekt_event.projekt_phase
    end

    def set_namespace
      @namespace = params[:controller].split("/").first.to_sym
    end
end
