Rails.application.config.to_prepare do
  ActiveStorage::DirectUploadsController.class_eval do
    before_action :authenticate_user!
    before_action :ensure_admin_user!

    private

      def ensure_admin_user!
        unless current_user.administrator?
          head :forbidden
        end
      end
  end
end
