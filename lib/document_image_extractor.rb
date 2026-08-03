# Pulls the raster images embedded in an office document. Kept separate from
# DocumentTextExtractor because most callers only want text, and unzipping or
# shelling out over a document is not free.
#
# DOCX and ODT are zip containers, so their images are readable with rubyzip
# alone. PDF images live in per-page XObject streams in a dozen encodings, often
# nested inside Form xobjects, with no extraction API in pdf-reader — they are
# read through poppler's pdfimages. Where that binary is absent the images are
# reported as present but unextractable, so the caller can tell the user to
# upload them by hand.
class DocumentImageExtractor < ApplicationService
  MAX_XOBJECT_DEPTH = 5

  # Enough to exclude logos, letterhead fragments and bullet glyphs without
  # discarding a photo that merely was not exported at print resolution.
  MIN_IMAGE_DIMENSION = 170

  # A slide deck exported to PDF can carry hundreds of objects; the import only
  # ever places a handful.
  MAX_PDF_IMAGES = 80

  # The probe only prints a version string; listing parses the whole object
  # table; extraction decodes every image, which is the one step a large
  # document can legitimately make slow.
  PROBE_TIMEOUT = 15.seconds
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

  # Only a positive result is memoized. Caching a negative would keep every
  # long-running worker reporting "not installed" after the package is added,
  # until someone restarts it; re-probing costs one short-lived process and only
  # happens while the binary is genuinely missing.
  def self.pdfimages_available?
    return true if @pdfimages_available

    @pdfimages_available = GuardedCommand.run(
      "pdfimages", "-v", timeout: PROBE_TIMEOUT
    ).success?
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
      ServiceResult.success(images: images_from_archive, unextractable: false)
    when "pdf"
      images_from_pdf
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
          width: nil,
          height: nil,
          data: entry.get_input_stream.read
        }
      end
    end

    # Both formats number their media sequentially in document order
    # (image1.png, image2.png, …), which a plain lexical sort would scramble
    # once the count passes nine.
    images.sort_by { |image| [image[:filename][/\d+/].to_i, image[:filename]] }
  end

  def images_from_pdf
    if !self.class.pdfimages_available?
      return ServiceResult.success(images: [], unextractable: pdf_contains_images?)
    end

    wanted = large_enough_pdf_entries

    if wanted.empty?
      ServiceResult.success(images: [], unextractable: false)
    else
      ServiceResult.success(images: extract_pdf_images(wanted), unextractable: false)
    end
  end

  # The listing is read before extracting so soft masks (the alpha channel of
  # another image, written as its own file by -png) and undersized logos never
  # reach the disk-read stage.
  def large_enough_pdf_entries
    result = GuardedCommand.run("pdfimages", "-list", file_path, timeout: LIST_TIMEOUT)

    if !result.success?
      warn_about_command("pdfimages -list", result)
      return []
    end

    parse_pdf_listing(result.stdout).select do |entry|
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
