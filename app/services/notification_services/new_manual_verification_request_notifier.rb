module NotificationServices
  class NewManualVerificationRequestNotifier < ApplicationService
    def initialize(user_to_verify_id)
      @user_to_verify_id = user_to_verify_id
    end

    def call
      users_to_notify.each do |user|
        NotificationServiceMailer.new_manual_verification_request(user.id, @user_to_verify_id).deliver_later
      end
    end

    private

      def users_to_notify
        [administrators]
          .flatten.uniq(&:id)
      end

      def administrators
        User.joins(:administrator).where(adm_email_on_new_manual_verification: true).to_a
      end
  end
end
