class Api::BaseController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods

  class ForbiddenError < StandardError; end
  class UnauthorizedError < StandardError; end

  DEFAULT_PER_PAGE = 500
  COMMENTS_PER_PAGE = 5000

  before_action :authenticate_api_client!
  rescue_from StandardError, with: :render_internal_server_error
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ForbiddenError, with: :render_forbidden
  rescue_from UnauthorizedError, with: :render_unauthorized

  private

  def authenticate_api_client!
    token = request.headers['Authorization']&.split(' ')&.last
    client = ApiClient.find_by(auth_token: token)

    if client.present?
      @current_client = client
    else
      raise UnauthorizedError, 'Invalid or missing API token.'
    end
  end

  def current_client
    @current_client
  end

  def check_read_access!
    unless current_client&.can_read_public_data?
      raise ForbiddenError, 'You do not have permission to read this resource.'
    end
  end

  def check_admin_access!
    unless current_client&.admin?
      raise ForbiddenError, 'You do not have permission to perform this action. Admin access required.'
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
      error: { type: "not_found", messages: ["Not found"]}
    }, status: 404
  end

  def render_internal_server_error(exception)
    raise exception unless Rails.env.production?

    render json: {
      error: {
        type: "internal_server_error",
        messages: ["Internal server error"]
      }
    }, status: 500
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
      filename: filename,
      type: content_type
    )

    @direct_upload = DirectUpload.new(
      {
        resource_relation: "image",
        resource_type: resource.class.name,
        attachment: uploaded_file,
        user: current_client.user
      }
    )

    if @direct_upload.valid?
      @direct_upload.save_attachment
      @direct_upload.relation.set_cached_attachment_from_attachment

      if resource.image.present?
        resource.image.destroy
      end

      @direct_upload.relation.imageable = resource
      @direct_upload.relation.save!

      resource.reload
    else
      raise StandardError, @direct_upload.errors.full_messages.join(", ")
    end
  ensure
    if new_temp_file
      new_temp_file.close
      new_temp_file.unlink
    end
  end

end
