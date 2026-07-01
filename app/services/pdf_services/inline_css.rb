require "base64"

module PdfServices::InlineCss
  CSS_PATH = Rails.root.join("app/assets/builds/application.adm.css")

  FONT_DIRS = [
    Rails.root.join("node_modules/@kern-ux/native/dist/fonts/fira-sans"),
    Rails.root.join("node_modules/material-symbols")
  ].freeze

  FONT_URL_PATTERN = /url\(["']?(\.\/[^"')]+\.woff2?)["']?\)/

  def self.call
    return "" if !File.exist?(CSS_PATH)

    mtime = File.mtime(CSS_PATH).to_i
    if @cache.nil? || @cache_mtime != mtime
      @cache = build_css
      @cache_mtime = mtime
    end

    @cache
  end

  def self.build_css
    File.read(CSS_PATH).gsub(FONT_URL_PATTERN) do |match|
      relative = Regexp.last_match(1)
      file = find_font(File.basename(relative))
      next match if file.nil?

      mime = relative.end_with?(".woff2") ? "font/woff2" : "font/woff"
      encoded = Base64.strict_encode64(File.binread(file))

      %(url("data:#{mime};base64,#{encoded}"))
    end
  end

  def self.find_font(basename)
    FONT_DIRS.each do |dir|
      path = dir.join(basename)
      return path if File.exist?(path)
    end

    nil
  end
end
