# The system shared libraries a headless Chrome needs to start. Puppeteer
# downloads the browser binary itself but not its runtime dependencies, so an
# instance can have the browser installed and still fail to launch it.
#
# Grouped by installable package rather than by library, because that is the
# unit an operator acts on: libnss3 ships three of the required files, so
# reporting them separately would ask for one apt package three times.
module HeadlessBrowser::RequiredLibraries
  PACKAGES = [
    { package: "libnss3", sonames: %w[libnss3.so libnssutil3.so libsmime3.so] },
    { package: "libnspr4", sonames: %w[libnspr4.so] },
    { package: "libatk1.0-0t64", sonames: %w[libatk-1.0.so.0] },
    { package: "libatk-bridge2.0-0t64", sonames: %w[libatk-bridge-2.0.so.0] },
    { package: "libxcomposite1", sonames: %w[libXcomposite.so.1] },
    { package: "libxdamage1", sonames: %w[libXdamage.so.1] },
    { package: "libxfixes3", sonames: %w[libXfixes.so.3] },
    { package: "libxrandr2", sonames: %w[libXrandr.so.2] },
    { package: "libgbm1", sonames: %w[libgbm.so.1] },
    { package: "libasound2t64", sonames: %w[libasound.so.2] },
    { package: "libatspi2.0-0t64", sonames: %w[libatspi.so.0] }
  ].freeze

  INSTALL_COMMAND = "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y " \
                    "#{PACKAGES.map { |entry| entry[:package] }.join(' ')}".freeze

  def self.supported?
    SharedLibrary.supported?
  end

  def self.packages_status
    available_sonames = SharedLibrary.sonames

    PACKAGES.each_with_object({}) do |entry, statuses|
      missing_sonames = entry[:sonames].reject { |soname| available_sonames.include?(soname) }

      statuses[entry[:package]] = {
        installed: missing_sonames.empty?,
        libraries: entry[:sonames],
        missing_libraries: missing_sonames
      }
    end
  end

  def self.missing_packages
    packages_status.reject { |_package, status| status[:installed] }.keys
  end
end
