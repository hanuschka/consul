class Api::NotificationsController < Api::BaseController
  before_action :find_projekt_phase, only: [:index, :create], if: -> { params[:projekt_phase_id].present? }
  before_action :find_projekt_notification, only: [:show, :update, :destroy]

  def index
    check_read_access!
    notifications = if @projekt_phase.present?
      @projekt_phase.projekt_notifications
        .includes(:projekt_phase, projekt_phase: :projekt)
    else
      ProjektNotification.includes(:projekt_phase, projekt_phase: :projekt)
    end

    notifications = paginate(notifications.order(created_at: :asc))

    serialized_notifications = NotificationSerializer.serialize_collection(notifications)

    render json: {
      data: { notifications: serialized_notifications },
      pagination: pagination_meta(notifications)
    }
  end

  def create
    check_admin_access!
    find_projekt_phase unless @projekt_phase.present?
    projekt_notification = @projekt_phase.projekt_notifications.new(projekt_notification_params)

    if projekt_notification.save
      serialized_projekt_notification = NotificationSerializer.new(projekt_notification).serialize

      render json: { data: { projekt_notification: serialized_projekt_notification } }, status: 201
    else
      render json: { error: { messages: projekt_notification.errors.full_messages } }, status: 422
    end
  end

  def show
    check_read_access!
    serialized_projekt_notification = NotificationSerializer.new(@projekt_notification).serialize

    render json: { data: { projekt_notification: serialized_projekt_notification } }
  end

  def update
    check_admin_access!
    if @projekt_notification.update(projekt_notification_params)
      serialized_projekt_notification = NotificationSerializer.new(@projekt_notification).serialize

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
      :body
    )
  end

  def find_projekt_phase
    @projekt_phase = ProjektPhase::ProjektNotificationPhase.find(params[:projekt_phase_id])
  end

  def find_projekt_notification
    @projekt_notification = ProjektNotification.includes(:projekt_phase, projekt_phase: :projekt).find(params[:id])
  end
end

