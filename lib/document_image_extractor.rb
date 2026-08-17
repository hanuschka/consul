# Pulls the raster images embedded in an office document. Kept separate from
# DocumentTextExtractor because most callers only want text, and unzipping or
# shelling out over a document is not free.
#
# DOCX and ODT are zip containers, so their media entries are readable with
# rubyzip alone, but the entry itself says nothing about the picture inside it:
# a zip records compressed bytes, and Word stores anything pasted from another
# Office program as a vector metafile no browser can display. Every candidate is
# therefore measured with ImageMagick, and the formats a browser cannot render
# are converted to PNG.
#
# PDF images live in per-page XObject streams in a dozen encodings, often nested
# inside Form xobjects, with no extraction API in pdf-reader — they are read
# through poppler's pdfimages. Where that binary is absent the images are
# reported as present but unextractable, so the caller can tell the user to
# upload them by hand.
class DocumentImageExtractor < ApplicationService
  MAX_XOBJECT_DEPTH = 5

  # Enough to exclude logos, letterhead fragments and bullet glyphs without
  # discarding a photo that merely was not exported at print resolution.
  MIN_IMAGE_DIMENSION = 170

  # A slide deck exported to PDF can carry hundreds of objects; the import only
  # ever places a handful. The archive formats get the same ceiling: a picture
  # book saved as DOCX would otherwise mean one ImageMagick run per page.
  MAX_PDF_IMAGES = 80
  MAX_ARCHIVE_IMAGES = 80

  # Guards the one step that is unbounded by the archive itself. An entry this
  # large is a print-resolution scan that no projekt page would use, and reading
  # it would mean holding it in memory to find that out.
  MAX_ARCHIVE_IMAGE_BYTES = 30.megabytes

  # Listing parses the whole object table; extraction decodes every image, which
  # is the one step a large document can legitimately make slow.
  LIST_TIMEOUT = 350.seconds
  EXTRACT_TIMEOUT = 380.seconds

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

  # Word writes a vector metafile for anything pasted from Excel or PowerPoint
  # and for its own drawing shapes, and a scanned page is routinely embedded as
  # TIFF. All of them are genuine content images that a browser cannot display,
  # so they are worth a conversion attempt.
  CONVERTIBLE_EXTENSIONS = %w[emf wmf tif tiff bmp].freeze

  # On most builds a metafile is decoded by handing it to LibreOffice, which is a
  # whole office suite starting up per image. A document built by pasting charts
  # out of Excel can hold dozens, and converting all of them would hold the
  # import queue for as long as the deadline allows — the ones past this point are
  # reported for manual upload instead.
  MAX_VECTOR_CONVERSIONS = 8
  VECTOR_EXTENSIONS = %w[emf wmf].freeze

  # Reasons an image was found and still could not be handed on, reported per
  # file so the caller can tell the admin which picture to upload by hand.
  UNREADABLE_UNDECODABLE = "undecodable".freeze
  UNREADABLE_CONVERSION_FAILED = "conversion_failed".freeze
  UNREADABLE_UNSUPPORTED = "unsupported_format".freeze
  UNREADABLE_TOO_LARGE = "too_large".freeze
  UNREADABLE_CONVERSION_LIMIT = "conversion_limit".freeze

  # Deliberately not memoized: a PATH lookup is a handful of stat calls, and
  # caching a negative would keep every long-running worker reporting "not
  # installed" after the package is added, until someone restarts it.
  def self.pdfimages_available?
    ExternalTool.installed?("pdfimages")
  end

  attr_reader :file, :file_path, :extension

  def initialize(file:)
    @file = file
    @file_path = file.path
    @extension = File.extname(file.original_filename).downcase.delete(".")
  end

  def call
    case extension
    when "docx", "odt"
      archive_result
    when "pdf"
      images_from_pdf
    else
      empty_result
    end
  rescue StandardError => e
    log_failure(e)
    empty_result
  end

  private

  def empty_result
    ServiceResult.success(images: [], unextractable: false, unreadable: [])
  end

  def log_failure(error)
    Rails.logger.warn("[DocumentImageExtractor] #{extension} failed: #{error.message}")
  end

  def archive_result
    images = []
    unreadable = []

    Zip::File.open(file_path) do |archive|
      media_entries(archive).each do |entry|
        if entry.size > MAX_ARCHIVE_IMAGE_BYTES
          unreadable << unreadable_entry(entry, UNREADABLE_TOO_LARGE)
          next
        end

        image = read_archive_entry(entry)

        if image[:reason].present?
          unreadable << unreadable_entry(entry, image[:reason])
          next
        end

        images << image
      end
    end

    ServiceResult.success(images: images, unextractable: false, unreadable: unreadable)
  end

  # Both formats number their media sequentially in document order
  # (image1.png, image2.png, …), which a plain lexical sort would scramble
  # once the count passes nine.
  def media_entries(archive)
    media_path = MEDIA_PATHS.fetch(extension)

    archive
      .select { |entry| entry.file? && entry.name.match?(media_path) }
      .sort_by { |entry| [File.basename(entry.name)[/\d+/].to_i, entry.name] }
      .first(MAX_ARCHIVE_IMAGES)
  end

  # Written to disk before anything is decided about it: ImageMagick needs a
  # path, and for a metafile the bytes that end up being kept are the converted
  # ones rather than the ones the archive held.
  def read_archive_entry(entry)
    entry_extension = File.extname(entry.name).downcase.delete(".")
    content_type = CONTENT_TYPES[entry_extension]

    if content_type.blank? && CONVERTIBLE_EXTENSIONS.exclude?(entry_extension)
      return { reason: UNREADABLE_UNSUPPORTED }
    end

    Dir.mktmpdir("archive_image") do |directory|
      source_path = File.join(directory, File.basename(entry.name))
      entry.extract(source_path)

      next convert_archive_entry(entry, source_path, directory) if content_type.blank?

      dimensions = ImageMagickCommand.dimensions(source_path)
      next { reason: UNREADABLE_UNDECODABLE } if dimensions.blank?

      descriptor(
        filename: File.basename(entry.name),
        content_type: content_type,
        path: source_path,
        dimensions: dimensions
      )
    end
  end

  def convert_archive_entry(entry, source_path, directory)
    entry_extension = File.extname(entry.name).downcase.delete(".")
    return { reason: UNREADABLE_UNSUPPORTED } if decodable_formats.exclude?(entry_extension)

    vector = VECTOR_EXTENSIONS.include?(entry_extension)

    if vector
      # Its own reason: the file is fine, the server simply stopped converting.
      # Reporting it as a failed conversion tells the admin to re-save a picture
      # that would have converted perfectly well.
      return { reason: UNREADABLE_CONVERSION_LIMIT } if @vector_conversions.to_i >= MAX_VECTOR_CONVERSIONS

      @vector_conversions = @vector_conversions.to_i + 1
    end

    converted_path = File.join(directory, "#{File.basename(entry.name, '.*')}.png")
    converted = ImageMagickCommand.convert_to_png(source_path, converted_path, vector: vector)
    return { reason: UNREADABLE_CONVERSION_FAILED } if !converted

    dimensions = ImageMagickCommand.dimensions(converted_path)
    return { reason: UNREADABLE_CONVERSION_FAILED } if dimensions.blank?

    descriptor(
      filename: "#{File.basename(entry.name, '.*')}.png",
      content_type: "image/png",
      path: converted_path,
      dimensions: dimensions
    )
  end

  def descriptor(filename:, content_type:, path:, dimensions:)
    {
      filename: filename,
      content_type: content_type,
      size: File.size(path),
      width: dimensions.first,
      height: dimensions.last,
      data: File.binread(path)
    }
  end

  def unreadable_entry(entry, reason)
    { filename: File.basename(entry.name), reason: reason }
  end

  # One listing per document rather than one per image: each call starts
  # ImageMagick and prints a few hundred lines.
  def decodable_formats
    @decodable_formats ||= ImageMagickCommand.decodable_formats
  end

  def images_from_pdf
    if !self.class.pdfimages_available?
      return ServiceResult.success(images: [], unextractable: pdf_contains_images?, unreadable: [])
    end

    listing = pdf_listing

    # An installed tool that could not list this document leaves the caller in
    # the same position as a missing one: there may be images in there and we
    # cannot get them out, so fall back to the probe and say so.
    if listing.nil?
      return ServiceResult.success(images: [], unextractable: pdf_contains_images?, unreadable: [])
    end

    wanted = large_enough_entries(listing)
    return empty_result if wanted.empty?

    ServiceResult.success(images: extract_pdf_images(wanted), unextractable: false, unreadable: [])
  end

  # The listing is read before extracting so soft masks (the alpha channel of
  # another image, written as its own file by -png) and undersized logos never
  # reach the disk-read stage. Returns nil when the command itself failed, which
  # is a different situation from a document holding no images.
  def pdf_listing
    result = GuardedCommand.run("pdfimages", "-list", file_path, timeout: LIST_TIMEOUT)

    if !result.success?
      warn_about_command("pdfimages -list", result)
      return nil
    end

    parse_pdf_listing(result.stdout)
  end

  def large_enough_entries(listing)
    listing.select do |entry|
      entry[:type] == "image" &&
        entry[:width] >= MIN_IMAGE_DIMENSION &&
        entry[:height] >= MIN_IMAGE_DIMENSION
    end
  end

  # Columns are "page num type width height …"; the two header rows and the
  # trailing columns are ignored.
  def parse_pdf_listing(listing)
    listing.each_line.filter_map do |line|
      columns = line.split
      next nil if columns.size < 5
      next nil if !columns[0].match?(/\A\d+\z/)

      {
        number: columns[1].to_i,
        type: columns[2],
        width: columns[3].to_i,
        height: columns[4].to_i
      }
    end
  end

  def extract_pdf_images(entries)
    directory = Dir.mktmpdir("pdfimages")

    begin
      result = GuardedCommand.run(
        "pdfimages", "-png", file_path, File.join(directory, "img"),
        timeout: EXTRACT_TIMEOUT
      )

      # A timeout still leaves whatever was written before the kill, and those
      # files are complete images — the listing is the authority on which ones
      # are wanted, so partial output is usable rather than discarded.
      warn_about_command("pdfimages -png", result) if !result.success?

      collect_extracted_files(directory, entries)
    ensure
      FileUtils.remove_entry(directory)
    end
  end

  # pdfimages names each file after the object number from the listing, zero
  # padded to a width that grows with the object count — the number is read back
  # out of the name rather than assumed to be three digits.
  def collect_extracted_files(directory, entries)
    wanted_numbers = entries.index_by { |entry| entry[:number] }
    digests = Set.new

    Dir.glob(File.join(directory, "img-*.png")).filter_map { |path|
      number = File.basename(path)[/-(\d+)\.png\z/, 1].to_i
      entry = wanted_numbers[number]
      next nil if entry.blank?

      data = File.binread(path)

      # The same logo or figure placed on every page is a separate object per
      # page, and would otherwise be embedded several times over.
      next nil if !digests.add?(Digest::SHA256.hexdigest(data))

      {
        filename: "pdf_image_#{number}.png",
        content_type: "image/png",
        size: data.bytesize,
        width: entry[:width],
        height: entry[:height],
        data: data,
        number: number
      }
    }.sort_by { |image| image[:number] }.first(MAX_PDF_IMAGES)
  end

  def warn_about_command(label, result)
    Rails.logger.warn(
      "[DocumentImageExtractor] #{label} #{result.failure_reason}: #{result.stderr.to_s.strip.truncate(300)}"
    )
  end

  def pdf_contains_images?
    require "pdf-reader"

    PDF::Reader.new(file_path).pages.any? { |page| image_in_xobjects?(page.xobjects, 0) }
  rescue StandardError => e
    Rails.logger.warn("[DocumentImageExtractor] pdf image probe failed: #{e.message}")
    false
  end

  # A page's own xobject list holds the top level only. Layout tools routinely
  # wrap a photo in a Form xobject, so a flat walk reports "no images" for a
  # document that plainly contains one. A depth cap stands in for cycle
  # detection: comparing the dereferenced dictionaries would mean hashing whole
  # image streams.
  def image_in_xobjects?(xobjects, depth)
    return false if depth > MAX_XOBJECT_DEPTH

    Array(xobjects).any? do |_name, stream|
      next false if !stream.is_a?(PDF::Reader::Stream)

      dictionary = stream.hash
      next true if dictionary[:Subtype] == :Image
      next false if dictionary[:Subtype] != :Form
      next false if !dictionary[:Resources].is_a?(Hash)

      image_in_xobjects?(dictionary[:Resources][:XObject], depth + 1)
    end
  end
end
