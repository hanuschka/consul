# Reads and converts image files through ImageMagick. Kept out of MiniMagick on
# purpose: the input here comes from a document an admin uploaded, so every run
# needs the deadline, memory cap and no-shell guarantees GuardedCommand gives,
# which MiniMagick only offers as a global setting.
#
# ImageMagick 7 ships "magick" and drops "convert"; 6 ships both "convert" and
# "identify". Either generation satisfies every method here.
module ImageMagickCommand
  DIMENSIONS_TIMEOUT = 20.seconds
  CONVERT_TIMEOUT = 60.seconds

  # A metafile is decoded by handing it to a delegate — on most builds
  # LibreOffice — which is a whole office suite starting up, so it gets its own
  # deadline and is allowed more address space than the 1 GB default would give
  # it.
  VECTOR_CONVERT_TIMEOUT = 150.seconds
  VECTOR_MEMORY_LIMIT = 3.gigabytes

  # Every image is addressed as "path[0]": a multi-page TIFF or an animated GIF
  # would otherwise report one line of dimensions per frame, and convert would
  # write one output file per frame.
  FIRST_FRAME = "[0]".freeze

  def self.dimensions(path)
    command = identify_command
    return nil if command.blank?

    result = GuardedCommand.run(
      *command, "-format", "%w %h", "#{path}#{FIRST_FRAME}",
      timeout: DIMENSIONS_TIMEOUT
    )

    if !result.success?
      Rails.logger.warn("[ImageMagickCommand] identify #{result.failure_reason}: #{result.stderr.to_s.strip.truncate(200)}")
      return nil
    end

    parse_dimensions(result.stdout)
  end

  def self.convert_to_png(source_path, destination_path, vector: false)
    command = convert_command
    return false if command.blank?

    # Flattened onto white because a metafile and a scan both routinely carry
    # transparency that a projekt page would render as a hole.
    result = GuardedCommand.run(
      *command, "#{source_path}#{FIRST_FRAME}",
      "-background", "white", "-flatten", "png:#{destination_path}",
      timeout: vector ? VECTOR_CONVERT_TIMEOUT : CONVERT_TIMEOUT,
      memory_limit: vector ? VECTOR_MEMORY_LIMIT : GuardedCommand::DEFAULT_MEMORY_LIMIT
    )

    if !result.success?
      Rails.logger.warn("[ImageMagickCommand] convert #{result.failure_reason}: #{result.stderr.to_s.strip.truncate(200)}")
      return false
    end

    File.size?(destination_path).present?
  end

  # A format is decodable either through a built-in coder or through a delegate
  # program. Metafiles are the case that matters: they appear in "-list delegate"
  # and not in "-list format", so checking only the format list reports a
  # perfectly convertible EMF as unsupported.
  #
  # A delegate entry is no promise that the program behind it is installed, so
  # the conversion itself still has to be allowed to fail.
  def self.decodable_formats
    listing = run_listing("-list", "format")
    formats = listing.to_s.scan(/^\s*([A-Z0-9]+)\*?\s+[A-Z0-9]+\s+[r-][w-]/).flatten

    delegates = run_listing("-list", "delegate").to_s.scan(/^\s*([a-z0-9]+)\s*=>/).flatten

    (formats.map(&:downcase) + delegates).uniq
  end

  def self.available?
    convert_command.present?
  end

  def self.identify_command
    return ["identify"] if ExternalTool.installed?("identify")
    return ["magick", "identify"] if ExternalTool.installed?("magick")

    nil
  end

  def self.convert_command
    return ["magick"] if ExternalTool.installed?("magick")
    return ["convert"] if ExternalTool.installed?("convert")

    nil
  end

  def self.run_listing(*arguments)
    command = convert_command
    return nil if command.blank?

    result = GuardedCommand.run(*command, *arguments, timeout: DIMENSIONS_TIMEOUT, output_limit: 4.megabytes)
    return nil if !result.success?

    result.stdout
  end

  def self.parse_dimensions(output)
    width, height = output.to_s.split.first(2).map(&:to_i)
    return nil if width.to_i <= 0 || height.to_i <= 0

    [width, height]
  end

  private_class_method :run_listing, :parse_dimensions
end
