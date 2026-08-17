# Carries the images stored on the import over into the created projekt: the one
# the admin chose in the chat becomes the title image, and the rest are stored as
# AdminImages so the content block renderer can reference them by URL.
#
# The pictures were extracted and attached to the import during analysis, so this
# stage reads them back rather than opening the source documents again — the admin
# has already seen these exact images and picked one of them.
class ProjektImports::AttachSourceImagesService < ApplicationService
  attr_reader :projekt_import, :projekt

  def initialize(projekt_import:, projekt:)
    @projekt_import = projekt_import
    @projekt = projekt
  end

  def call
    candidates = projekt_import.source_image_candidates.select { |candidate| candidate.attachment.present? }
    return ServiceResult.success(hero_attached: false, image_urls: []) if candidates.empty?

    hero = attach_hero(candidates)
    embeddable = hero.present? ? candidates - [hero] : candidates

    ServiceResult.success(
      hero_attached: hero.present?,
      image_urls: embeddable.filter_map { |candidate| store_admin_image(candidate) }
    )
  rescue StandardError => e
    Rails.logger.error("[ProjektImports::AttachSourceImagesService] failed: #{e.message}")
    Sentry.capture_exception(e, extra: { projekt_import_id: projekt_import.id, stage: "source_images" }) if defined?(Sentry)
    projekt_import.add_warning!(I18n.t("adm.projekts.imports.warnings.source_images_failed", message: e.message))

    ServiceResult.success(hero_attached: false, image_urls: [])
  end

  private

  # Warnings about images that could not be read are not repeated here: they were
  # reported during analysis, when the admin could still act on them.
  def attach_hero(candidates)
    return nil if !projekt_import.title_image_document?
    return nil if projekt.page&.image.present?

    hero = candidates.find { |candidate| candidate.index == projekt_import.title_image_index }
    return nil if hero.blank?

    result = ::Projekts::AttachPageImageService.call(
      projekt: projekt,
      user: projekt_import.user,
      data: hero.attachment.blob.download,
      filename: "projekt_#{projekt.id}_hero#{File.extname(hero.filename)}",
      content_type: hero.attachment.blob.content_type
    )

    if !result.success?
      projekt_import.add_warning!(
        I18n.t("adm.projekts.imports.warnings.source_image_hero_rejected", image: hero.filename)
      )
      return nil
    end

    hero
  end

  def store_admin_image(candidate)
    blob = candidate.attachment.blob
    file = Tempfile.new(["projekt_import_image", File.extname(candidate.filename)], binmode: true)

    begin
      file.write(blob.download)
      file.rewind

      admin_image = ::AdminImage.new(user: projekt_import.user, projekt: projekt)
      admin_image.attach_processed_upload(
        ActionDispatch::Http::UploadedFile.new(
          tempfile: file,
          filename: candidate.filename,
          type: blob.content_type
        )
      )
      admin_image.save!

      # Path, not URL: these land in content blocks rendered on the projekt
      # page itself, the same as an editor upload.
      admin_image.url_content
    rescue StandardError => e
      projekt_import.add_warning!(
        I18n.t("adm.projekts.imports.warnings.source_image_store_failed", image: candidate.filename, message: e.message)
      )
      nil
    ensure
      file.close
      file.unlink
    end
  end
end
