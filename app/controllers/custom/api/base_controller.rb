class Api::BaseController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods

  class ForbiddenError < StandardError; end
  class UnauthorizedError < StandardError; end

  before_action :authenticate_api_client!
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
        messages: exception.message
      }
    }, status: :forbidden
  end

  def render_unauthorized(exception)
    render json: {
      error: {
        type: "unauthorized",
        messages: exception.message
      }
    }, status: :unauthorized
  end

  def render_not_found
    render json: {
      error: { type: "not_found", messages: ["Not found"]}
    }, status: 404
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
      return create_or_update_image_from_base64(resource, image_data)
    end

    if resource.image.present?
      resource.image.update!(image_data.except(:_destroy, :attachment))
      return resource.image
    end

    nil
  end

  private

  def create_or_update_image_from_base64(resource, image_data)
    base64_string = image_data[:attachment]
    temp_file = Base64ImageUtils.decode_to_tempfile(base64_string)

    begin
      content_type = Base64ImageUtils.content_type_from_string(base64_string)
      extension = Base64ImageUtils.extension_from_content_type(content_type)
      filename = "image.#{extension}"

      user = User.administrators.first
      raise "No user available to associate with the image. Please ensure at least one administrator exists." unless user

      image_attrs = image_data.except(:_destroy, :attachment).merge(user: user)

      if resource.image.present?
        image = resource.image
        image.assign_attributes(image_attrs)
        temp_file.rewind
        image.attachment.attach(io: temp_file, filename: filename, content_type: content_type)
        image.save!
      else
        image = Image.new(image_attrs.merge(imageable: resource))
        temp_file.rewind
        image.attachment.attach(io: temp_file, filename: filename, content_type: content_type)
        image.save!
        resource.image = image
      end

      image
    ensure
      temp_file&.close
      temp_file&.unlink
    end
  end
end
