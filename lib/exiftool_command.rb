# Reads and writes image metadata by shelling out to exiftool, following the
# same guarded-subprocess pattern as ImageMagickCommand.
#
# exiftool rewrites only the metadata segments of a JPEG and leaves the
# compressed pixel data untouched, which is why marking runs through it rather
# than through ImageMagick: a re-encode would change the picture, and every
# re-encode is what destroyed the generator's own provenance record in the
# first place.
#
# Marking a generated image is mandatory, so an unusable binary is reported
# with the reason rather than being treated as "no marker this time" -- the
# caller turns that into a visible failure.
module ExiftoolCommand
  # Metadata-only rewrites of a single image are fast. The deadline is generous
  # against a cold page cache rather than against the work itself.
  TIMEOUT = 20.seconds

  BINARY = "exiftool".freeze

  READY = :ready
  BINARY_MISSING = :binary_missing

  INSTALL_COMMAND = "apt-get install -y libimage-exiftool-perl  # macOS: brew install exiftool".freeze

  # Only a healthy result is memoised. A binary that is on PATH cannot leave it
  # under a running process, so that answer is worth keeping. A failure is
  # re-probed because the usual cause is a box that has not been provisioned
  # yet: once the package arrives it recovers on the next attempt rather than
  # waiting for a restart.
  def self.runtime_status
    return @runtime_status if @runtime_status == READY

    @runtime_status = binary_path.present? ? READY : BINARY_MISSING
  end

  def self.available?
    runtime_status == READY
  end

  def self.binary_path
    @binary_path ||= ENV["EXIFTOOL_PATH"].presence || discovered_binary_path
  end

  # Searched in Ruby rather than through `which`, so probing costs no
  # subprocess on a path that already runs one per image.
  def self.discovered_binary_path
    ENV["PATH"].to_s.split(File::PATH_SEPARATOR).lazy
      .map { |directory| File.join(directory, BINARY) }
      .find { |candidate| File.executable?(candidate) }
  end

  def self.run(*arguments)
    GuardedCommand.run(binary_path.to_s, *arguments, timeout: TIMEOUT)
  end

  # Returns the value of a single tag, or nil when the tag is absent. -s3 gives
  # the bare value with no tag name or padding, which is what a caller comparing
  # it against a known constant needs.
  def self.read_tag(path, tag)
    result = run("-s3", "-#{tag}", path.to_s)

    return nil if !result.success?

    result.stdout.to_s.strip.presence
  end
end
