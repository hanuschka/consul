class Api::BaseController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods
  include ActionController::HttpAuthentication::Basic::ControllerMethods

  class ForbiddenError < StandardError; end
  class UnauthorizedError < StandardError; end

  DEFAULT_PER_PAGE = 500
  COMMENTS_PER_PAGE = 5000

  before_action :authenticate_http_basic, if: :http_basic_auth_site?
  before_action :authenticate_api_client!
  after_action :log_api_request

  # rescue_from StandardError, with: :render_internal_server_error
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ForbiddenError, with: :render_forbidden
  rescue_from UnauthorizedError, with: :render_unauthorized

  private

    def authenticate_http_basic
      authenticate_or_request_with_http_basic do |username, password|
        username == Rails.application.secrets.http_basic_username && password == Rails.application.secrets.http_basic_password
      end
    end

    def http_basic_auth_site?
      Rails.application.secrets.http_basic_auth
    end

    def authenticate_api_client!
      token = request.headers["Authorization"]&.split(" ")&.last
      client = ApiClient.find_by(access_token: token)

      if client.present?
        @current_client = client
        @internal_api_client = false
      else
        internal_client = InternalApiClient.find_by(auth_token: token)

        if internal_client.present?
          @current_client = internal_client
          @internal_api_client = true
        else
          raise UnauthorizedError, "Invalid or missing API token."
        end
      end
    end

    def current_client
      @current_client
    end

    def internal_api_client?
      @internal_api_client == true
    end

    def check_read_access!
      return if internal_api_client?

      unless current_client&.can_read_public_data?
        raise ForbiddenError, "You do not have permission to read this resource."
      end
    end

    def check_admin_access!
      return if internal_api_client?

      unless current_client&.admin?
        raise ForbiddenError, "You do not have permission to perform this action. Admin access required."
      end
    end

    def render_forbidden(exception)
      render json: {
        error: {
          type: "forbidden",
          messages: [exception.message]
        }
      }, status: :forbidden
    end

    def render_unauthorized(exception)
      render json: {
        error: {
          type: "unauthorized",
          messages: [exception.message]
        }
      }, status: :unauthorized
    end

    def render_not_found
      render json: {
        error: { type: "not_found", messages: ["Not found"] }
      }, status: :not_found
    end

    def log_api_request
      return if skip_api_request_log?

      ApiRequestLogs::CreateAndPushJob.perform_later(
        request.method,
        request.path,
        request.url,
        request.query_parameters.to_h,
        request.request_parameters.to_h,
        response.status,
        @current_client&.id
      )
    rescue StandardError
    end

    SKIP_LOG_RESPONSE_STATUSES = [401, 403, 404, 405].freeze

    def skip_api_request_log?
      SKIP_LOG_RESPONSE_STATUSES.include?(response.status)
    end

    def render_internal_server_error(exception)
      raise exception if !Rails.env.production?

      Sentry.capture_exception(exception)
      Rails.logger.error("[API] #{exception.class} (#{exception.message}):\n#{exception.backtrace.join("\n")}")

      render json: {
        error: {
          type: "internal_server_error",
          messages: ["Internal server error"]
        }
      }, status: :internal_server_error
    end

  protected

  # Processes base64-encoded image data and creates/updates an Image resource
  # @param resource [Object] The imageable resource (Project, Proposal, etc.)
  # @param image_data [Hash] Hash containing :title, :attachment, :credits, :_destroy
  # @return [Image, nil] The updated/created Image object or nil if destroyed
  # @raises [StandardError] If base64 decoding or image operations fail
    def process_image_with_base64(resource, image_data)
      return nil if image_data.blank?

      if ActiveModel::Type::Boolean.new.cast(image_data[:_destroy])
        resource.image&.destroy
        return nil
      end

      if image_data[:attachment].present?
        return update_image_with_attachment(resource, image_data)
      end

      nil
    end

  private

    def update_image_with_attachment(resource, image_attrs)
      attachment_data = image_attrs[:attachment]
      content_type = Base64ImageUtils.content_type_from_string(attachment_data)
      extension = Base64ImageUtils.extension_from_content_type(content_type)
      filename = "image.#{extension}"

      new_temp_file = Base64ImageUtils.decode_to_tempfile(attachment_data)
      uploaded_file = ActionDispatch::Http::UploadedFile.new(
        tempfile: new_temp_file,
        filename:,
        type: content_type
      )

      if resource.image.nil?
        image = Image.new(
          attachment: uploaded_file,
          user: User.administrators.first || User.first,
          imageable: resource
        )
        image.save!
      else
        resource.image.attachment.attach(uploaded_file)
      end

    ensure
      if new_temp_file
        new_temp_file.close
        new_temp_file.unlink
      end
    end
end
