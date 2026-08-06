# The projekt hero image lives on the projekt's page as a polymorphic ::Image,
# and every writer of it needs the same four steps: build or reuse the record,
# wrap the bytes in an UploadedFile, set the owner, reset the association so the
# caller sees the new attachment.
class Projekts::AttachPageImageService < ApplicationService
  attr_reader :projekt, :user, :data, :filename, :content_type

  def initialize(projekt:, user:, data:, filename:, content_type:)
    @projekt = projekt
    @user = user
    @data = data
    @filename = filename
    @content_type = content_type
  end

  def call
    page = projekt.page

    if page.blank?
      return ServiceResult.failure(error: "projekt has no page to attach the image to")
    end

    file = Tempfile.new(["projekt_page_image", File.extname(filename)], binmode: true)

    begin
      file.write(data)
      file.rewind

      image = page.image || ::Image.new(imageable: page)
      image.attachment = ActionDispatch::Http::UploadedFile.new(
        tempfile: file,
        filename: filename,
        type: content_type
      )
      image.user = user
      image.save!
      page.association(:image).reset

      ServiceResult.success(image: image)
    ensure
      file.close
      file.unlink
    end
  rescue StandardError => e
    Rails.logger.error("[Projekts::AttachPageImageService] failed: #{e.message}")
    ServiceResult.failure(error: e.message)
  end
end
