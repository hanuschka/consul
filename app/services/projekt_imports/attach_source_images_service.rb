# Carries the images embedded in the uploaded source documents over into the
# created projekt: the first one becomes the hero unless the admin asked for an
# AI-generated banner, and the rest are stored as AdminImages so the content
# block renderer can reference them by URL.
class ProjektImports::AttachSourceImagesService < ApplicationService
  MIN_IMAGE_BYTES = 10_000
  ALLOWED_CONTENT_TYPES = ::AdminImage::ALLOWED_CONTENT_TYPES

  attr_reader :projekt_import, :projekt

  def initialize(projekt_import:, projekt:)
    @projekt_import = projekt_import
    @projekt = projekt
  end

  def call
    images = collect_images
    return ServiceResult.success(hero_attached: false, image_urls: []) if images.empty?

    hero_attached = attach_hero(images.first)
    embeddable = hero_attached ? images.drop(1) : images

    ServiceResult.success(
      hero_attached: hero_attached,
      image_urls: embeddable.filter_map { |image| store_admin_image(image) }
    )
  rescue StandardError => e
    Rails.logger.error("[ProjektImports::AttachSourceImagesService] failed: #{e.message}")
    Sentry.capture_exception(e, extra: { projekt_import_id: projekt_import.id, stage: "source_images" }) if defined?(Sentry)
    projekt_import.add_warning!("source_images: #{e.message}")

    ServiceResult.success(hero_attached: false, image_urls: [])
  end

  private

  def collect_images
    projekt_import.source_files.flat_map { |source_file| images_from(source_file) }
  end

  def images_from(source_file)
    result = ::AttachmentUpload.open(source_file) do |file|
      ::DocumentImageExtractor.call(file: file)
    end

    if result.data[:unextractable]
      projekt_import.add_warning!(
        I18n.t("adm.projekts.imports.warnings.pdf_images_tool_missing",
          filename: source_file.blob.filename.to_s)
      )
    end

    result.data[:images].select { |image| usable?(image) }
  end

  # Documents are full of logos, bullets and letterhead fragments. Pixel
  # dimensions are the honest measure and the PDF path reports them; the zip
  # formats hand back compressed bytes only, where a byte floor is the cheap
  # stand-in. A byte floor alone would misjudge PDFs badly — an uncompressed
  # 144x145 logo weighs 20 KB.
  def usable?(image)
    return false if ALLOWED_CONTENT_TYPES.exclude?(image[:content_type])

    if image[:width].present? && image[:height].present?
      return image[:width] >= ::DocumentImageExtractor::MIN_IMAGE_DIMENSION &&
             image[:height] >= ::DocumentImageExtractor::MIN_IMAGE_DIMENSION
    end

    image[:size].to_i >= MIN_IMAGE_BYTES
  end

  def attach_hero(image)
    return false if projekt_import.generate_image
    return false if projekt.page&.image.present?

    result = ::Projekts::AttachPageImageService.call(
      projekt: projekt,
      user: projekt_import.user,
      data: image[:data],
      filename: "projekt_#{projekt.id}_hero#{File.extname(image[:filename])}",
      content_type: image[:content_type]
    )

    if !result.success?
      projekt_import.add_warning!("source_image_hero: #{result.error}")
      return false
    end

    true
  end

  def store_admin_image(image)
    file = Tempfile.new(["projekt_import_image", File.extname(image[:filename])], binmode: true)

    begin
      file.write(image[:data])
      file.rewind

      admin_image = ::AdminImage.new(user: projekt_import.user, projekt: projekt)
      admin_image.attach_processed_upload(
        ActionDispatch::Http::UploadedFile.new(
          tempfile: file,
          filename: image[:filename],
          type: image[:content_type]
        )
      )
      admin_image.save!

      # Path, not URL: these land in content blocks rendered on the projekt
      # page itself, the same as an editor upload.
      admin_image.url_content
    rescue StandardError => e
      projekt_import.add_warning!("source_image(#{image[:filename]}): #{e.message}")
      nil
    ensure
      file.close
      file.unlink
    end
  end
end
