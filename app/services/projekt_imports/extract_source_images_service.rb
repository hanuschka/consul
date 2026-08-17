# Pulls the pictures out of the uploaded documents and keeps them on the import,
# while the admin is still in the chat. Three things depend on running this before
# the analysis call rather than at submit time: the model has to know images exist
# to pick a content block template that has a place for one, the admin has to be
# able to look at the candidates and choose a title image, and an image that
# cannot be carried over has to be reported while there is still time to upload it
# by hand.
#
# The bytes are stored on the import rather than re-extracted at submit time so
# that what the admin picked is exactly what gets attached, and so a PDF is only
# ever decoded once.
class ProjektImports::ExtractSourceImagesService < ApplicationService
  INELIGIBLE_TOO_SHORT = "too_short".freeze
  INELIGIBLE_CONTENT_TYPE = "content_type".freeze

  attr_reader :projekt_import

  def initialize(projekt_import:)
    @projekt_import = projekt_import
  end

  # Each document and each picture inside it is isolated, because a single failure
  # used to discard everything: one flat_map over all files meant a blob upload
  # that raised on the second document threw away the descriptors for the first
  # one's pictures, leaving them attached but invisible to the picker, the prompt
  # and the projekt — reported to the admin as "no usable image was found".
  def call
    descriptors = projekt_import.source_files.flat_map { |source_file| images_from(source_file) }

    projekt_import.update!(
      source_images: descriptors,
      title_image_index: default_title_image_index(descriptors)
    )

    ServiceResult.success(source_images: descriptors)
  rescue StandardError => e
    report(e)

    ServiceResult.success(source_images: [])
  end

  private

  def images_from(source_file)
    store_images_from(source_file)
  rescue StandardError => e
    report(e, filename: source_file.blob.filename.to_s)
    projekt_import.add_warning!(
      I18n.t("adm.projekts.imports.warnings.source_images_file_failed",
             filename: source_file.blob.filename.to_s),
      stage: ProjektImport::ANALYSIS_WARNING_STAGE
    )

    []
  end

  def report(error, filename: nil)
    Rails.logger.error("[ProjektImports::ExtractSourceImagesService] failed: #{error.message}")
    return if !defined?(Sentry)

    Sentry.capture_exception(
      error,
      extra: { projekt_import_id: projekt_import.id, stage: "source_images", filename: filename }.compact
    )
  end

  def store_images_from(source_file)
    filename = source_file.blob.filename.to_s

    result = ::AttachmentUpload.open(source_file) do |file|
      ::DocumentImageExtractor.call(file: file)
    end

    warn_about_unextractable(filename) if result.data[:unextractable]
    result.data[:unreadable].each { |image| warn_about_unreadable(filename, image) }

    ProjektImports::SourceImageFilter.usable(result.data[:images]).filter_map do |image|
      stored_descriptor_for(image, filename)
    end
  end

  # One picture that cannot be stored costs that picture and says so, rather than
  # the whole document's worth.
  def stored_descriptor_for(image, filename)
    descriptor_for(image, filename)
  rescue StandardError => e
    report(e, filename: filename)
    projekt_import.add_warning!(
      I18n.t("adm.projekts.imports.warnings.source_image_store_failed",
             image: image[:filename], message: e.message),
      stage: ProjektImport::ANALYSIS_WARNING_STAGE
    )

    nil
  end

  def descriptor_for(image, source_filename)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(image[:data]),
      filename: image[:filename],
      content_type: image[:content_type]
    )

    # Written straight onto the blob because the dimensions are already known
    # from the extraction: letting Active Storage analyze the file later would
    # run ImageMagick over every picture a second time, and the picker needs the
    # numbers before that job would have finished.
    blob.update!(
      metadata: blob.metadata.merge(
        "width" => image[:width], "height" => image[:height], "analyzed" => true
      )
    )
    projekt_import.extracted_images.attach(blob)

    {
      "source_filename" => source_filename,
      "filename" => image[:filename],
      "content_type" => image[:content_type],
      "width" => image[:width],
      "height" => image[:height],
      "blob_id" => blob.id,
      "eligible" => title_image_eligible?(image),
      "ineligible_reason" => ineligible_reason_for(image)
    }
  end

  def title_image_eligible?(image)
    ineligible_reason_for(image).nil?
  end

  # Ordered by what the admin can do about it: a format the instance does not
  # accept at all is worth saying before the height, which they could crop.
  def ineligible_reason_for(image)
    return INELIGIBLE_CONTENT_TYPE if !ProjektImports::SourceImageFilter.hero_content_type?(image)
    return INELIGIBLE_TOO_SHORT if image[:height].to_i < ::Image::MIN_IMAGE_HEIGHT

    nil
  end

  # Preselected rather than left empty so an import submitted without opening the
  # picker still carries the document's image over, which is the behaviour the
  # picker was added on top of.
  def default_title_image_index(descriptors)
    hero = ProjektImports::SourceImageFilter.hero_candidate(symbolized(descriptors))
    return nil if hero.blank?

    descriptors.index { |descriptor| descriptor["blob_id"] == hero[:blob_id] }
  end

  def symbolized(descriptors)
    descriptors.map(&:symbolize_keys)
  end

  # Two different causes, so two different messages: an admin who can have the
  # package installed should be told that, and an admin whose server is fine
  # should not be sent chasing a package that is already there.
  def warn_about_unextractable(filename)
    key =
      if ::DocumentImageExtractor.pdfimages_available?
        "adm.projekts.imports.warnings.pdf_images_unreadable"
      else
        "adm.projekts.imports.warnings.pdf_images_tool_missing"
      end

    projekt_import.add_warning!(
      I18n.t(key, filename: filename),
      stage: ProjektImport::ANALYSIS_WARNING_STAGE
    )
  end

  def warn_about_unreadable(filename, image)
    projekt_import.add_warning!(
      I18n.t(
        "adm.projekts.imports.warnings.source_image_#{image[:reason]}",
        filename: filename,
        image: image[:filename]
      ),
      stage: ProjektImport::ANALYSIS_WARNING_STAGE
    )
  end
end
