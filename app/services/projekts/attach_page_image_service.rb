# The projekt hero image lives on the projekt's page as a polymorphic ::Image,
# and every writer of it needs the same steps: build or reuse the record, wrap
# the bytes in an UploadedFile, set the owner and whether the picture came from
# an image generator, reset the association so the caller sees the new
# attachment.
class Projekts::AttachPageImageService < ApplicationService
  attr_reader :projekt, :user, :data, :filename, :content_type, :ai_generated

  def initialize(projekt:, user:, data:, filename:, content_type:, ai_generated: false)
    @projekt = projekt
    @user = user
    @data = data
    @filename = filename
    @content_type = content_type
    @ai_generated = ai_generated
  end

  def call
    page = projekt.page

    if page.blank?
      return ServiceResult.failure(error: "projekt has no page to attach the image to")
    end

    image = page.image || ::Image.new(imageable: page)
    attachment_data = ai_generated ? marked_data(image) : data

    file = Tempfile.new(["projekt_page_image", File.extname(filename)], binmode: true)

    begin
      file.write(attachment_data)
      file.rewind

      image.attachment = ActionDispatch::Http::UploadedFile.new(
        tempfile: file,
        filename: filename,
        type: content_type
      )
      image.user = user
      image.ai_generated = ai_generated
      image.save!
      page.association(:image).reset

      ServiceResult.success(image: image)
    ensure
      file.close
      file.unlink
    end
  rescue ::Images::MarkAiGeneratedService::MarkingFailedError
    ServiceResult.failure(error: I18n.t("custom.ai.errors.marking_unavailable"))
  rescue StandardError => e
    Rails.logger.error("[Projekts::AttachPageImageService] failed: #{e.message}")
    ServiceResult.failure(error: e.message)
  end

  private

    def marked_data(image)
      ::Images::MarkAiGeneratedService.call(
        image: image,
        data: data,
        filename: filename,
        content_type: content_type
      ).data[:image_data]
    end
end
