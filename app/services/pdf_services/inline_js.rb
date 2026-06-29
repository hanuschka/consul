module PdfServices::InlineJs
  JS_PATH = Rails.root.join("app/assets/builds/application-kern.js")

  def self.call
    return "" if !File.exist?(JS_PATH)

    mtime = File.mtime(JS_PATH).to_i
    if @cache.nil? || @cache_mtime != mtime
      @cache = File.read(JS_PATH)
      @cache_mtime = mtime
    end

    @cache
  end
end
