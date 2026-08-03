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

  def self.installed?(tool)
    tool[:commands].any? { |command| ExternalTool.installed?(command) }
  end
end
