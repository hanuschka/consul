# Pulls the raster images embedded in an office document. Kept separate from
# DocumentTextExtractor because most callers only want text, and unzipping a
# document to read its media directory is not free.
#
# DOCX and ODT are zip containers, so their images are readable with rubyzip
# alone. PDF images live in per-page XObject streams in a dozen encodings with
# no extraction API in pdf-reader — those are reported as present but
# unextractable so the caller can tell the user to upload them by hand.
class DocumentImageExtractor < ApplicationService
  MEDIA_PATHS = {
    "docx" => %r{\Aword/media/}i,
    "odt" => %r{\APictures/}i
  }.freeze

  CONTENT_TYPES = {
    "jpg" => "image/jpeg",
    "jpeg" => "image/jpeg",
    "png" => "image/png",
    "gif" => "image/gif",
    "webp" => "image/webp",
    "avif" => "image/avif"
  }.freeze

  attr_reader :file, :file_path, :extension

  def initialize(file:)
    @file = file
    @file_path = file.path
    @extension = File.extname(file.original_filename).downcase.delete(".")
  end

  def call
    case extension
    when "docx", "odt"
      ServiceResult.success(images: images_from_archive, unextractable: false)
    when "pdf"
      ServiceResult.success(images: [], unextractable: pdf_contains_images?)
    else
      ServiceResult.success(images: [], unextractable: false)
    end
  rescue StandardError => e
    Rails.logger.warn("[DocumentImageExtractor] #{extension} failed: #{e.message}")
    ServiceResult.success(images: [], unextractable: false)
  end

  private

  def images_from_archive
    media_path = MEDIA_PATHS.fetch(extension)
    images = []

    Zip::File.open(file_path) do |archive|
      archive.each do |entry|
        next if !entry.file?
        next if !entry.name.match?(media_path)

        content_type = CONTENT_TYPES[File.extname(entry.name).downcase.delete(".")]
        next if content_type.blank?

        images << {
          filename: File.basename(entry.name),
          content_type: content_type,
          size: entry.size,
          data: entry.get_input_stream.read
        }
      end
    end

    # Both formats number their media sequentially in document order
    # (image1.png, image2.png, …), which a plain lexical sort would scramble
    # once the count passes nine.
    images.sort_by { |image| [image[:filename][/\d+/].to_i, image[:filename]] }
  end

  def pdf_contains_images?
    require "pdf-reader"

    PDF::Reader.new(file_path).pages.any? do |page|
      page.xobjects.any? { |_name, stream| stream.hash[:Subtype] == :Image }
    end
  rescue StandardError => e
    Rails.logger.warn("[DocumentImageExtractor] pdf image probe failed: #{e.message}")
    false
  end
end
