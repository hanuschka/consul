class Adm::WhatsappQrCodeComponent < ApplicationComponent
  QR_MODULE_SIZE = 8

  def initialize(title:, subline:, token: nil)
    @title = title
    @subline = subline
    @token = token
  end

  attr_reader :title, :subline, :token

  def deep_link
    @deep_link ||= ::Whatsapp.deep_link_url_for(@token)
  end

  def qr_svg
    @qr_svg ||= ::Whatsapp.qr_svg(deep_link, module_size: QR_MODULE_SIZE)
  end

  # PDF poster disabled for now — restore together with the qr_poster route,
  # the controller action and the download button in the template.
  # def poster_path
  #   helpers.qr_poster_adm_whatsapp_path(token: @token, format: :pdf)
  # end

  def download_basename
    ["whatsapp-qr", @token.presence].compact.join("-").parameterize
  end

  def business_number
    ::Whatsapp.business_number.presence
  end
end
