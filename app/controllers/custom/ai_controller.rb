class AiController < ApplicationController
  skip_authorization_check
  before_action :authenticate_user!

  DEFICIENCY_REPORT_CODENAME = "deficiency_report_voice_assistant".freeze

  ASSIGNABLE_RESOURCE_TYPES = {
    "Proposal" => Proposal,
    "Budget::Investment" => Budget::Investment
  }.freeze

  def generate_image
    if params[:codename] == DEFICIENCY_REPORT_CODENAME
      render json: { error: "Image generation not available" }, status: :forbidden
      return
    end

    response = DtApi::Client.new.ai.generate_image(prompt: params[:prompt], aspect_ratio: params[:aspect_ratio])

    unless response.success?
      Sentry.capture_message(
        "Ai generate_image failed",
        level: "error",
        extra: {
          status: response.code,
          body: response.parsed_response,
          codename: params[:codename]
        }
      )
    end

    if response.success?
      mark_resource_generated_image
    end

    render json: response.parsed_response, status: response.code
  end

  def generate_image_and_assign_to_resource
    if params[:codename] == DEFICIENCY_REPORT_CODENAME
      render json: { error: "Image generation not available" }, status: :forbidden
      return
    end

    resource = find_assignable_resource

    if resource.nil?
      render json: { error: "Resource not found" }, status: :not_found
      return
    end

    image_response = DtApi::Client.new.ai.generate_image(prompt: params[:prompt], aspect_ratio: params[:aspect_ratio])

    unless image_response.success?
      Sentry.capture_message(
        "Ai generate_image_and_assign_to_resource failed",
        level: "error",
        extra: {
          status: image_response.code,
          body: image_response.parsed_response,
          codename: params[:codename]
        }
      )
      render json: image_response.parsed_response, status: image_response.code
      return
    end

    attach_generated_image(resource, image_response.parsed_response["image"])
    resource.update_column(:generated_image, true)
    resource.reload

    render json: { image_url: image_url(resource.image.attachment) }
  end

  def remove_image_from_resource
    resource = find_assignable_resource

    if resource.blank?
      render json: { error: "Resource not found" }, status: :not_found
      return
    end

    if resource.respond_to?(:draft) && !resource.draft
      render json: { error: "Resource is not a draft" }, status: :forbidden
      return
    end

    resource.image&.destroy

    render json: { success: true }
  end

  private

    def find_assignable_resource
      resource_class = ASSIGNABLE_RESOURCE_TYPES[params[:resource_type]]
      return nil if resource_class.blank?

      resource_class.unscoped.find_by(id: params[:resource_id])
    end

    def mark_resource_generated_image
      resource = find_assignable_resource
      return if resource.blank?

      resource.update_column(:generated_image, true)
    end

    def attach_generated_image(resource, base64_image)
      new_temp_file = Base64ImageUtils.decode_to_tempfile(base64_image)
      uploaded_file = ActionDispatch::Http::UploadedFile.new(
        tempfile: new_temp_file,
        filename: "ai_generated_#{Time.current.to_i}.jpg",
        type: "image/jpeg"
      )

      image = resource.image || Image.new(user: current_user, imageable: resource)
      image.attachment = uploaded_file
      image.ai_generated = true
      image.save!
    end

    def image_url(attachment)
      Rails.application.routes.url_helpers.rails_blob_url(attachment, only_path: true)
    end
end
