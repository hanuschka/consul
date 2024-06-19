class NotificationsController < ApplicationController
  before_action :authenticate_user!
  skip_authorization_check

  respond_to :html, :js

  def index
    @notifications = current_user.notifications.unread
  end

  def show
    @notification = current_user.notifications.find(params[:id])
    @notification.mark_as_read
    redirect_to linkable_resource_path(@notification)
  end

  def read
    @notifications = current_user.notifications.read
  end

  def mark_all_as_read
    current_user.notifications.unread.each(&:mark_as_read)
    redirect_to notifications_path
  end

  def mark_as_read
    @notification = current_user.notifications.find(params[:id])
    @notification.mark_as_read
  end

  def mark_as_unread
    @notification = current_user.notifications.find(params[:id])
    @notification.mark_as_unread
  end

  private

    def linkable_resource_path(notification)
      if notification.linkable_resource.is_a?(AdminNotification)
        notification.linkable_resource.link || notifications_path
      elsif notification.notifiable_type.in?(["ProjektQuestion", "ProjektEvent", "ProjektLivestream", "ProjektNotification"]) # custom
        "/#{notification.notifiable.projekt.page.slug}?projekt_phase_id=#{notification.notifiable.projekt_phase.id}#filter-subnav"
      elsif notification.notifiable_type.in?(["ProjektPhase"]) # custom
        "/#{notification.notifiable.projekt.page.slug}?projekt_phase_id=#{notification.notifiable.id}#filter-subnav"
      else
        polymorphic_path(notification.linkable_resource)
      end
    end
end
