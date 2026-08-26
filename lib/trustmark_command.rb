# Embeds an invisible watermark into a generated image by shelling out to the
# TrustMark runtime, following the same guarded-subprocess pattern as
# ImageMagickCommand.
#
# The runtime is Python with PyTorch behind it, which costs roughly 800 MB
# resident and about 1.6 seconds of model loading per invocation. Both are
# reasons to keep it in a short-lived subprocess rather than in the Rails
# process: the memory is never held between images and never accumulates in a
# long-lived worker.
#
# TRUSTMARK_PYTHON points at the interpreter of the virtualenv holding the
# trustmark package. Marking is mandatory, so an unusable runtime is reported
# with the reason it is unusable rather than being treated as "no watermark
# this time" -- the caller turns that into a visible failure.
module TrustmarkCommand
  # Model load dominates: roughly 1.6 s, then about 180 ms to encode and 60 ms
  # to verify on a 3-core production box. The deadline is generous against a
  # cold page cache rather than against the work itself.
  TIMEOUT = 90.seconds

  # No address-space cap. PyTorch reserves hundreds of gigabytes of address
  # space while residing in under a gigabyte, so RLIMIT_AS cannot be set to any
  # value that both admits a normal run and constrains a runaway one -- measured
  # at roughly 416 GB of virtual size for a single encode. A cap sized by
  # resident memory would kill every run, and since marking is mandatory that
  # would block AI image generation outright. The deadline below is what bounds
  # a wedged process instead.
  MEMORY_LIMIT = nil

  # The encoder carries exactly this many usable bits at BCH_5 error
  # correction. A longer payload is truncated on decode rather than rejected on
  # encode, so identifiers are generated at exactly this width.
  PAYLOAD_BITS = 61

  # Leaves the box a core to serve requests with while an image is being
  # marked.
  THREADS = 2

  SCRIPT_PATH = Rails.root.join("lib", "trustmark", "embed_watermark.py").freeze

  READY = :ready
  INTERPRETER_MISSING = :interpreter_missing
  SCRIPT_MISSING = :script_missing
  LIBRARIES_MISSING = :libraries_missing

  # The python packages the encoder needs. torchvision is pulled in as a
  # dependency and is not probed separately: an operator installs it as part of
  # the same command either way.
  PACKAGES = %w[torch trustmark].freeze

  # The CPU wheel index is part of the instruction rather than a footnote:
  # resolving torch from PyPI installs the CUDA build, which costs an extra
  # 250 MB resident and gigabytes of unused NVIDIA libraries on a box with no
  # GPU.
  INSTALL_COMMAND = "python3 -m venv /opt/trustmark && " \
                    "/opt/trustmark/bin/pip install " \
                    "--index-url https://download.pytorch.org/whl/cpu torch torchvision && " \
                    "/opt/trustmark/bin/pip install trustmark".freeze

  # find_spec locates the packages without importing them: importing torch
  # alone costs well over a second, and the question here is only whether it is
  # installed at all.
  IMPORT_PROBE = <<~PYTHON.freeze
    import importlib.util, sys
    names = #{PACKAGES.inspect}
    missing = [n for n in names if importlib.util.find_spec(n) is None]
    sys.stdout.write(",".join(missing))
    sys.exit(1 if missing else 0)
  PYTHON

  PROBE_TIMEOUT = 30.seconds

  # Memoised: the answer cannot change without the process being restarted, and
  # every generated image would otherwise pay for the probe.
  def self.runtime_status
    @runtime_status ||= probe_runtime
  end

  def self.available?
    runtime_status == READY
  end

  def self.packages_status
    missing = missing_packages

    PACKAGES.each_with_object({}) do |package, statuses|
      statuses[package] = { installed: !missing.include?(package) }
    end
  end

  # Without a usable interpreter nothing can be found, so every package counts
  # as missing rather than unknown -- the operator has the same work to do.
  def self.missing_packages
    if runtime_status == INTERPRETER_MISSING
      return PACKAGES
    end

    @missing_packages || []
  end

  # Names the packages the probe could not find, for an operator reading a log
  # or an error page.
  def self.missing_libraries
    missing_packages.join(", ")
  end

  def self.probe_runtime
    if python_path.blank? || !File.executable?(python_path.to_s)
      return INTERPRETER_MISSING
    end

    if !File.exist?(SCRIPT_PATH)
      return SCRIPT_MISSING
    end

    result = GuardedCommand.run(
      python_path.to_s, "-c", IMPORT_PROBE,
      timeout: PROBE_TIMEOUT,
      memory_limit: MEMORY_LIMIT
    )

    if result.success?
      return READY
    end

    @missing_packages = result.stdout.to_s.strip.split(",").map(&:strip).presence || PACKAGES

    LIBRARIES_MISSING
  end

  # Generates an identifier for one image. Stored as hex because 61 bits is not
  # a byte boundary and the bit string is only the encoder's own wire format.
  def self.generate_identifier
    SecureRandom.random_number(2**PAYLOAD_BITS).to_s(16).rjust(16, "0")
  end

  def self.payload_for(identifier)
    identifier.to_i(16).to_s(2).rjust(PAYLOAD_BITS, "0")
  end

  # Writes a watermarked copy of source_path to destination_path. Returns true
  # only when the subprocess also verified the mark survived the save.
  def self.embed(source_path, destination_path, identifier)
    return false if !available?

    result = GuardedCommand.run(
      python_path.to_s, SCRIPT_PATH.to_s,
      "--input", source_path.to_s,
      "--output", destination_path.to_s,
      "--payload", payload_for(identifier),
      "--threads", THREADS.to_s,
      timeout: TIMEOUT,
      memory_limit: MEMORY_LIMIT
    )

    if !result.success?
      Rails.logger.warn(
        "[TrustmarkCommand] embed #{result.failure_reason}: #{failure_detail(result)}"
      )

      return false
    end

    File.size?(destination_path).present?
  end

  # Conventional venv locations, tried in order when TRUSTMARK_PYTHON is unset:
  # the system-wide path a provisioned server uses, then a per-user one a
  # developer can create without root. Having defaults matters because marking
  # is mandatory -- a box that installed the runtime where the README says to
  # should not also need an environment variable to be usable.
  DEFAULT_PYTHON_PATHS = [
    "/opt/trustmark/bin/python",
    File.expand_path("~/.local/share/trustmark/bin/python")
  ].freeze

  def self.python_path
    @python_path ||= ENV["TRUSTMARK_PYTHON"].presence || discovered_python_path
  end

  def self.discovered_python_path
    DEFAULT_PYTHON_PATHS.find { |path| File.executable?(path) }
  end

  # The script reports its own errors as JSON on stdout; stderr carries the
  # interpreter's own noise, which is what matters when the script never ran.
  def self.failure_detail(result)
    parsed = JSON.parse(result.stdout.to_s)
    parsed["error"].presence || result.stderr.to_s.strip.truncate(200)
  rescue JSON::ParserError
    result.stderr.to_s.strip.truncate(200)
  end
end
