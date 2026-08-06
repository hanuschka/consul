class Adm::WhatsappQrCodeComponent < ApplicationComponent
  QR_MODULE_SIZE = 4

  def initialize(title:, subline:, token: nil, prefilled_text: nil)
    @title = title
    @subline = subline
    @token = token
    @prefilled_text = prefilled_text
  end

  attr_reader :title, :subline, :token

  def deep_link
    @deep_link ||= ::Whatsapp.deep_link_url(@prefilled_text.presence || greeting)
  end

  def qr_svg
    return if deep_link.blank?

    @qr_svg ||=
      RQRCode::QRCode.new(deep_link).as_svg(
        module_size: QR_MODULE_SIZE,
        standalone: true,
        use_path: true,
        viewbox: true
      )
  end

  def business_number
    ::Whatsapp.business_number.presence
  end

  private

    def greeting
      I18n.t("adm.whatsapp.greeting")
    end
end
