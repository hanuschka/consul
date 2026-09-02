# The command line tools the projekt import depends on, and which part of the
# import stops working without each one. Used to warn an admin on the import
# screen before they upload a document that cannot be processed.
#
# Each entry lists every command that satisfies the requirement: ImageMagick 7
# ships "magick" and drops "convert", so either is enough.
module ProjektImports::RequiredTools
  TOOLS = [
    { key: "pandoc", commands: %w[pandoc], package: "pandoc" },
    { key: "pdftotext", commands: %w[pdftotext], package: "poppler-utils" },
    { key: "pdfimages", commands: %w[pdfimages], package: "poppler-utils" },
    { key: "imagemagick", commands: %w[magick convert], package: "imagemagick" }
  ].freeze

  def self.missing
    TOOLS.reject { |tool| installed?(tool) }
  end

  # Grouped by installable package rather than by tool, because that is the
  # unit an operator acts on: pdftotext and pdfimages both come from
  # poppler-utils, so reporting them separately would ask for one apt package
  # twice.
  def self.packages_status
    TOOLS.group_by { |tool| tool[:package] }.transform_values do |tools|
      missing_tools = tools.reject { |tool| installed?(tool) }

      {
        installed: missing_tools.empty?,
        commands: tools.flat_map { |tool| tool[:commands] },
        missing_commands: missing_tools.flat_map { |tool| tool[:commands] }
      }
    end
  end

  def self.missing_packages
    packages_status.reject { |_package, status| status[:installed] }.keys
  end

  def self.installed?(tool)
    tool[:commands].any? { |command| ExternalTool.installed?(command) }
  end
end
