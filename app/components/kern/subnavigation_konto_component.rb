class Kern::SubnavigationKontoComponent < ApplicationComponent
  def initialize(current_user:)
    @current_user = current_user
  end

  attr_reader :current_user

  def user_image_present?
    current_user.image&.variant(:popup).present?
  end

  def unread_notifications?
    current_user.notifications.unread.count > 0
  end
end
