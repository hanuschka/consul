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

Rails.application.config.to_prepare do
  ActiveStorage::Representations::BaseController.class_eval do
    rescue_from "MiniMagick::Error", "MiniMagick::Invalid", with: :serve_unprocessed_blob

    private

      def serve_unprocessed_blob(exception)
        Rails.logger.error("[ActiveStorage] representation failed, serving original: #{exception.message}")
        Sentry.capture_exception(exception, level: :warning) if defined?(Sentry)

        if @blob.present?
          expires_in ActiveStorage.service_urls_expire_in
          redirect_to @blob.url(disposition: params[:disposition])
        else
          head :not_found
        end
      end
  end
end
