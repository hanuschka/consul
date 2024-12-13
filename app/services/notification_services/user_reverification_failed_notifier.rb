module NotificationServices
  class UserReverificationFailedNotifier < ApplicationService
    def initialize(user_id)
      @user_id = user_id
    end

    def call
      NotificationServiceMailer.user_reverification_failed(@user_id).deliver_later
    end
  end
end
