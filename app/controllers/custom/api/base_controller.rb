class Api::BaseController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods
  include ActionController::HttpAuthentication::Basic::ControllerMethods

  class ForbiddenError < StandardError; end
  class UnauthorizedError < StandardError; end

  DEFAULT_PER_PAGE = 500
  COMMENTS_PER_PAGE = 5000
  MAX_PER_PAGE = 2000

  before_action :authenticate_http_basic, if: :require_http_basic_auth?
  before_action :authenticate_api_client!

  BODY_PARAM_MAX_BYTES = 8192

  rescue_from StandardError, with: :render_internal_server_error
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

    def require_http_basic_auth?
      http_basic_auth_site? && !bearer_token_provided?
    end

    def bearer_token_provided?
      request.authorization.to_s.match?(/\ABearer /i)
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

    def paginate(scope, default_per_page: DEFAULT_PER_PAGE)
      scope.page(params[:page].to_s).per(requested_per_page(default_per_page))
    end

    def pagination_meta(collection)
      {
        current_page: collection.current_page,
        total_pages: collection.total_pages,
        total_count: collection.total_count,
        per_page: collection.limit_value
      }
    end

    def empty_pagination_meta(default_per_page: DEFAULT_PER_PAGE)
      {
        current_page: 1,
        total_pages: 0,
        total_count: 0,
        per_page: requested_per_page(default_per_page)
      }
    end

    def requested_per_page(default_per_page)
      cap = [MAX_PER_PAGE, default_per_page].max
      requested = params[:per_page].to_s.to_i

      if requested < 1
        default_per_page
      else
        [requested, cap].min
      end
    end

    def no_pagination_meta
      {
        message: "All matching records were returned in a single response " \
          "without pagination. To paginate, supply the 'page' and/or " \
          "'per_page' query parameters (for example: ?page=1&per_page=20)."
      }
    end

    def append_info_to_payload(payload)
      super
      return if skip_api_request_log?

      payload[:api_request_log] = {
        full_url: request.url,
        query_params: request.query_parameters.to_h,
        body_params: loggable_body_params,
        api_client_id: @current_client&.id
      }
    rescue StandardError
    end

    def loggable_body_params
      request.request_parameters.to_h.deep_transform_values do |value|
        if value.is_a?(String) && value.bytesize > BODY_PARAM_MAX_BYTES
          "[truncated #{value.bytesize} bytes]"
        else
          value
        end
      end
    end

    SKIP_LOG_RESPONSE_STATUSES = [401, 403, 404, 405].freeze

    def skip_api_request_log?
      return true if @current_client.blank?

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
  # @param image_data [Hash] Hash containing :title, :attachment, :credits, :ai_generated, :_destroy
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

      image = resource.image
      return nil if image.blank?

      assign_image_fields(image, image_data)
      image.save!

      image
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

      image = resource.image || Image.new(
        user: User.administrators.first || User.first,
        imageable: resource
      )

      # Assigned and saved through the record rather than attached directly:
      # attachment.attach writes immediately and skips the model callbacks, so
      # the AI marker of the picture being replaced would survive onto the new
      # file.
      image.attachment = uploaded_file
      assign_image_fields(image, image_attrs)
      image.save!

      image

    ensure
      if new_temp_file
        new_temp_file.close
        new_temp_file.unlink
      end
    end

    # The image's own fields travel in the same hash as the attachment, and are
    # documented as writable, so a payload that carries only them still has to
    # land on the existing image.
    def assign_image_fields(image, image_attrs)
      image.title = image_attrs[:title] if image_attrs.key?(:title)
      image.credits = image_attrs[:credits] if image_attrs.key?(:credits)

      if image_attrs.key?(:ai_generated)
        image.ai_generated = ActiveModel::Type::Boolean.new.cast(image_attrs[:ai_generated]) == true
      end
    end
end
