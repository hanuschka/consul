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

  READY = :ready
  BINARY_MISSING = :binary_missing

  RECOVERY_COMMAND = "bundle install  # the binary ships with the exiftool_vendored gem".freeze

  # The releases where the two optional parts of the marking start working.
  # Below them exiftool only warns -- "Not a deletable group: jumbf", "Tag ...
  # is not defined" -- and still exits 0, because the rest of the write
  # succeeded. A capability therefore has to be decided from the version before
  # the arguments are built; it cannot be read back off the result.
  #
  # 12.64 is the release that added JUMBF to the deletable groups. 13.55 is the
  # oldest build the AI system tags were confirmed present in, and 13.00 does
  # not have them, so anything between the two is treated as lacking them and
  # records no system rather than asking for a tag it cannot write.
  JUMBF_DELETE_VERSION = Gem::Version.new("12.64")
  AI_SYSTEM_TAG_VERSION = Gem::Version.new("13.55")

  # Only a healthy result is memoised. The binary ships with the bundle and so
  # cannot leave it under a running process, which makes that answer worth
  # keeping. A failure is re-probed because the usual cause is a bundle that has
  # not finished installing yet: once the gem arrives it recovers on the next
  # attempt rather than waiting for a restart.
  def self.runtime_status
    return @runtime_status if @runtime_status == READY

    @runtime_status = binary_path.present? ? READY : BINARY_MISSING
  end

  def self.available?
    runtime_status == READY
  end

  def self.binary_path
    @binary_path ||= ENV["EXIFTOOL_PATH"].presence || vendored_binary_path
  end

  # The bundled copy is the only one guaranteed to be there, and the only one
  # whose version is known: an OS package is routinely older than the gem and
  # writes some of the tags this app marks with as a warning rather than an
  # error, which reads as success. A PATH copy is therefore not consulted at
  # all -- ENV["EXIFTOOL_PATH"] stays the way to point at a specific build.
  def self.vendored_binary_path
    return nil if !defined?(::ExiftoolVendored)

    candidate = ::ExiftoolVendored.path_to_exiftool.to_s

    candidate if File.executable?(candidate)
  end

  # nil when the binary is unusable or its answer unparseable, which every
  # capability predicate below reads as "not supported". Memoised like
  # runtime_status: only a real answer is kept, so a process whose bundle
  # finishes installing later recovers on the next call.
  def self.version
    @version ||= probe_version
  end

  def self.probe_version
    return nil if binary_path.blank?

    result = run("-ver")

    return nil if !result.success?

    Gem::Version.new(result.stdout.to_s.strip)
  rescue ArgumentError
    nil
  end

  def self.supports_jumbf_delete?
    version.present? && version >= JUMBF_DELETE_VERSION
  end

  def self.supports_ai_system_tags?
    version.present? && version >= AI_SYSTEM_TAG_VERSION
  end

  # Whether everything the marking writes actually lands. Reported rather than
  # enforced: an older binary still writes the source type every verification
  # tool reads, and refusing to mark at all would take image generation down on
  # a portal that is merely behind.
  def self.full_marking_supported?
    supports_jumbf_delete? && supports_ai_system_tags?
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
