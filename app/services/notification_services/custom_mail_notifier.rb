module NotificationServices
  class CustomMailNotifier < ApplicationService
    def initialize(title, body)
      @title = title
      @body = body
    end

    def call
      users_to_notify.each do |user|
        Mailer.custom_mail(user, @title, @body).deliver_later
      end
    end

    private

      def users_to_notify
        User.active.where(guest: false, hidden_at: nil).limit(3)
      end
  end
end
