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
    add_analysis_warning("source_images_file_failed", filename: source_file.blob.filename.to_s)

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

    descriptors = ProjektImports::SourceImageFilter.usable(result.data[:images]).filter_map do |image|
      stored_descriptor_for(image, filename)
    end

    # One attach for the document rather than one per picture: Attached::Many#attach
    # reloads the association and saves the record on every call, so attaching
    # forty images one at a time is forty growing SELECTs and forty saves.
    attach(descriptors)

    descriptors
  end

  def attach(descriptors)
    return if descriptors.empty?

    projekt_import.extracted_images.attach(*descriptors.map { |descriptor| descriptor["blob"] })
    descriptors.each { |descriptor| descriptor.delete("blob") }
  end

  # One picture that cannot be stored costs that picture and says so, rather than
  # the whole document's worth.
  def stored_descriptor_for(image, filename)
    descriptor_for(image, filename)
  rescue StandardError => e
    report(e, filename: filename)
    add_analysis_warning("source_image_store_failed", image: image[:filename], message: e.message)

    nil
  end

  # The dimensions go onto the blob as it is created because they are already
  # known from the extraction: letting Active Storage analyze the file later would
  # run ImageMagick over every picture a second time, and the picker needs the
  # numbers before that job would have finished.
  #
  # Only why an image cannot be the title image is stored, never a matching
  # "eligible" boolean — two stored fields for one fact can disagree in rows
  # written by different versions of the rule.
  def descriptor_for(image, source_filename)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(image[:data]),
      filename: image[:filename],
      content_type: image[:content_type],
      metadata: { "width" => image[:width], "height" => image[:height], "analyzed" => true }
    )

    {
      "source_filename" => source_filename,
      "filename" => image[:filename],
      "width" => image[:width],
      "height" => image[:height],
      "blob_id" => blob.id,
      "ineligible_reason" => ineligible_reason_for(image),
      "blob" => blob
    }
  end

  def ineligible_reason_for(image)
    return INELIGIBLE_CONTENT_TYPE if !ProjektImports::SourceImageFilter.hero_content_type?(image)

    nil
  end

  # Preselected rather than left empty so an import submitted without opening the
  # picker still carries the document's image over, which is the behaviour the
  # picker was added on top of. Read back off the descriptors rather than re-run
  # against the extractor's hashes: the answer is already in them.
  def default_title_image_index(descriptors)
    descriptors.index { |descriptor| descriptor["ineligible_reason"].blank? }
  end

  # Every warning this service raises describes the uploaded files, so the stage is
  # stated once here. Stating it per call site is how a new warning silently
  # becomes a submit-stage one and gets wiped on the next import attempt.
  def add_analysis_warning(key, **interpolations)
    projekt_import.add_warning!(
      I18n.t("adm.projekts.imports.warnings.#{key}", **interpolations),
      stage: ProjektImport::ANALYSIS_WARNING_STAGE
    )
  end

  # Two different causes, so two different messages: an admin who can have the
  # package installed should be told that, and an admin whose server is fine
  # should not be sent chasing a package that is already there.
  def warn_about_unextractable(filename)
    key =
      if ::DocumentImageExtractor.pdfimages_available?
        "pdf_images_unreadable"
      else
        "pdf_images_tool_missing"
      end

    add_analysis_warning(key, filename: filename)
  end

  def warn_about_unreadable(filename, image)
    add_analysis_warning("source_image_#{image[:reason]}", filename: filename, image: image[:filename])
  end
end
