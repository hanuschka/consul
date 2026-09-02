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

      begin
        render json: marked_payload(response.parsed_response), status: response.code
      rescue Images::MarkAiGeneratedService::MarkingFailedError
        render json: { error: I18n.t("custom.ai.errors.marking_unavailable") },
               status: :service_unavailable
      end

      return
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

    begin
      attach_generated_image(resource, image_response.parsed_response)
    rescue Images::MarkAiGeneratedService::MarkingFailedError
      render json: { error: I18n.t("custom.ai.errors.marking_unavailable") },
             status: :service_unavailable
      return
    end

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

    def attach_generated_image(resource, response_body)
      filename = "ai_generated_#{Time.current.to_i}.jpg"
      image = resource.image || Image.new(user: current_user, imageable: resource)
      marked_data = marked_image_data(
        response_body["image"],
        filename: filename,
        image: image,
        response_body: response_body
      )
      file = attachment_tempfile(marked_data)

      begin
        image.attachment = ActionDispatch::Http::UploadedFile.new(
          tempfile: file,
          filename: filename,
          type: "image/jpeg"
        )
        image.ai_generated = true
        image.save!
      ensure
        file.close
        file.unlink
      end
    end

    def marked_payload(parsed_response)
      base64_image = parsed_response["image"]
      return parsed_response if base64_image.blank?

      marked_data = marked_image_data(
        base64_image,
        filename: "ai_generated_#{Time.current.to_i}.jpg",
        image: ::Image.new,
        response_body: parsed_response
      )

      parsed_response.merge("image" => Base64.strict_encode64(marked_data))
    end

    def marked_image_data(base64_image, filename:, image:, response_body: {})
      generated_file = Base64ImageUtils.decode_to_tempfile(base64_image)

      begin
        Images::MarkAiGeneratedService.call(
          image: image,
          data: File.binread(generated_file.path),
          filename: filename,
          content_type: "image/jpeg",
          ai_system: DtApi::Resources::Ai.reported_provider(response_body),
          ai_system_version: DtApi::Resources::Ai.reported_model(response_body)
        ).data[:image_data]
      ensure
        generated_file.close
        generated_file.unlink
      end
    end

    def attachment_tempfile(data)
      file = Tempfile.new(["ai_generated", ".jpg"], binmode: true)
      file.write(data)
      file.rewind

      file
    end

    def image_url(attachment)
      Rails.application.routes.url_helpers.rails_blob_url(attachment, only_path: true)
    end
end
