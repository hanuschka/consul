class Shared::ModalNotificationComponent < ApplicationComponent
  delegate :cookies, to: :helpers

  def initialize
  end

  def render?
    klaro_cookie_present? && modal_notification.present?
  end

  private

    def modal_notification
      @modal_notification ||= ModalNotification.current
    end

    def klaro_cookie_present?
      cookies[:klaro]
    end
end
