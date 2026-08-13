# Answers "can the dynamic linker find this shared library" by reading the
# ldconfig cache instead of scanning directories. The cache is the same list
# dlopen consults, so a hit means the library really is loadable no matter
# which path the distribution package used.
#
# ldconfig lives in sbin, which is not on PATH for every deploy user, so the
# usual locations are probed before falling back to a PATH lookup.
module SharedLibrary
  LDCONFIG_CANDIDATES = ["/usr/sbin/ldconfig", "/sbin/ldconfig"].freeze

  # "\tlibgbm.so.1 (libc6,x86-64) => /lib/x86_64-linux-gnu/libgbm.so.1"
  ENTRY_PATTERN = /\A\s+(\S+)\s+\(/.freeze

  def self.supported?
    ldconfig_path.present?
  end

  def self.sonames
    path = ldconfig_path
    return Set.new if path.blank?

    read_cache(path)
  end

  def self.ldconfig_path
    found = LDCONFIG_CANDIDATES.find { |candidate| File.executable?(candidate) }

    found || ExternalTool.path_for("ldconfig")
  end

  def self.read_cache(path)
    output = IO.popen([path, "-p"], err: File::NULL, &:read)

    return Set.new if output.blank?

    output.each_line.with_object(Set.new) do |line, sonames|
      match = ENTRY_PATTERN.match(line)
      sonames << match[1] if match
    end
  rescue SystemCallError, IOError
    Set.new
  end
end
