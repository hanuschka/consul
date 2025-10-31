class Api::ProjektNotificationsController < Api::BaseController
  before_action :find_projekt_phase, only: [:create]
  before_action :find_projekt_notification, only: [:show, :update, :destroy]

  def create
    check_admin_access!
    projekt_notification = @projekt_phase.projekt_notifications.new(projekt_notification_params)

    if projekt_notification.save
      serialized_projekt_notification = ProjektNotificationSerializer.new(projekt_notification).serialize

      render json: { data: { projekt_notification: serialized_projekt_notification } }, status: 201
    else
      render json: { error: { messages: projekt_notification.errors.full_messages } }, status: 422
    end
  end

  def show
    check_read_access!
    serialized_projekt_notification = ProjektNotificationSerializer.new(@projekt_notification).serialize

    render json: { data: { projekt_notification: serialized_projekt_notification } }
  end

  def update
    check_admin_access!
    if @projekt_notification.update(projekt_notification_params)
      serialized_projekt_notification = ProjektNotificationSerializer.new(@projekt_notification).serialize

      render json: { data: { projekt_notification: serialized_projekt_notification } }
    else
      render json: { error: { messages: @projekt_notification.errors.full_messages } }, status: 422
    end
  end

  def destroy
    check_admin_access!
    if @projekt_notification.destroy
      render json: { message: "Projekt notification destroyed" }
    else
      render json: { error: { messages: @projekt_notification.errors.messages } }, status: 422
    end
  end

  private

  def projekt_notification_params
    params.require(:projekt_notification).permit(
      :title,
      :body,
      :link_text,
      :link_url,
      :segment_recipient
    )
  end

  def find_projekt_phase
    @projekt_phase = ProjektPhase::ProjektNotificationPhase.find(params[:projekt_phase_id])
  end

  def find_projekt_notification
    @projekt_notification = ProjektNotification.find(params[:id])
  end
end

