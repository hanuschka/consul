module NotificationServices
  class UserReverificationSucceededNotifier < ApplicationService
    def initialize(user_id)
      @user_id = user_id
    end

    def call
      NotificationServiceMailer.user_reverification_succeeded(@user_id).deliver_later
    end
  end
end
