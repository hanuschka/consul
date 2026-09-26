module PdfServices::WhatsappQrPosterCss
  CSS_PATH = Rails.root.join("app/assets/stylesheets/pdf/whatsapp_qr_poster.css")

  def self.call
    return "" if !File.exist?(CSS_PATH)

    mtime = File.mtime(CSS_PATH).to_i

    if @cache.nil? || @cache_mtime != mtime
      @cache = File.read(CSS_PATH)
      @cache_mtime = mtime
    end

    @cache
  end
end
