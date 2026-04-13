module PdfServices
  class BaseService < ApplicationService
    include Rails.application.routes.url_helpers
    include TextWithLinksHelper

    COLORS = {
      header_bg: "e8ecf4",
      header_text: "2c3e6b",
      primary: "1a1a2e",
      secondary: "666666",
      accent: "2c3e6b",
      card_bg: "f6f7fa",
      border: "d0d5dd",
      white: "ffffff"
    }.freeze

    private

      def setup_fonts(pdf)
        font_path = Rails.root.join("app/assets/fonts/custom/Asap-Variable.ttf")
        pdf.font_families.update("Asap" => { normal: font_path, bold: font_path, italic: font_path, bold_italic: font_path })
        pdf.font "Asap"
      end

      def render_header_banner(pdf, title_text:, qr_url: nil)
        banner_height = 70
        qr_size = 50

        pdf.canvas do
          pdf.fill_color COLORS[:header_bg]
          pdf.fill_rectangle([0, pdf.bounds.top], pdf.bounds.width, banner_height)
        end

        if qr_url
          qr_y = pdf.bounds.top - (banner_height - qr_size) / 2
          pdf.fill_color COLORS[:white]
          pdf.fill_rounded_rectangle([pdf.bounds.width - 40 - qr_size - 5, qr_y + 5], qr_size + 10, qr_size + 10, 3)
          pdf.svg(generate_qr_svg(qr_url), at: [pdf.bounds.width - 40 - qr_size, qr_y], width: qr_size)
          title_width = pdf.bounds.width - 80 - qr_size - 30
        else
          title_width = pdf.bounds.width - 80
        end

        title_y = pdf.bounds.top - (banner_height - 20) / 2
        pdf.bounding_box([40, title_y], width: title_width, height: 24) do
          pdf.text title_text, size: 18, style: :bold, color: COLORS[:header_text], overflow: :shrink_to_fit, valign: :center
        end

        pdf.fill_color COLORS[:primary]
        pdf.move_cursor_to pdf.bounds.top - banner_height - 16
      end

      def render_meta_card(pdf, rows)
        card_height = rows.length * 20 + 24

        pdf.fill_color COLORS[:card_bg]
        pdf.fill_rounded_rectangle([0, pdf.cursor], pdf.bounds.width, card_height, 4)
        pdf.fill_color COLORS[:primary]

        pdf.stroke_color COLORS[:border]
        pdf.rounded_rectangle([0, pdf.cursor], pdf.bounds.width, card_height, 4)
        pdf.stroke

        pdf.bounding_box([14, pdf.cursor - 12], width: pdf.bounds.width - 28, height: card_height - 24) do
          rows.each do |label, value|
            pdf.formatted_text [
              { text: "#{label}:  ", size: 10, styles: [:bold], color: COLORS[:secondary] },
              { text: value.to_s, size: 10, color: COLORS[:primary] }
            ]
            pdf.move_down 4
          end
        end

        pdf.move_down card_height + 16
      end

      def render_title_and_description(pdf, title:, description_html:)
        pdf.text title, size: 14, style: :bold, color: COLORS[:accent]
        pdf.move_down 6

        description = html_to_paragraphs(description_html)
        return unless description.present?

        pdf.text description, size: 10, color: COLORS[:primary], leading: 4, inline_format: true
        pdf.move_down 16
      end

      def render_labeled_rows(pdf, rows, size: 9)
        return if rows.empty?

        rows.each do |label, value|
          pdf.formatted_text [
            { text: "#{label}:  ", size: size, styles: [:bold], color: COLORS[:secondary] },
            { text: value.to_s, size: size, color: COLORS[:primary] }
          ]
          pdf.move_down 3
        end

        pdf.move_down 12
      end

      def render_map_image(pdf, map_location)
        return unless map_location&.screenshot.present?

        render_safe_image(pdf, map_location.screenshot, width: pdf.bounds.width)
      end

      def render_attachment_image(pdf, image)
        return unless image&.attachment&.attached?

        render_safe_image(pdf, image.attachment, width: [pdf.bounds.width, 360].min)
      end

      def render_footer(pdf)
        pdf.repeat(:all) do
          pdf.bounding_box([40, 25], width: pdf.bounds.width - 80, height: 20) do
            pdf.stroke_color COLORS[:border]
            pdf.stroke_horizontal_rule
            pdf.move_down 6
            pdf.fill_color COLORS[:secondary]
            pdf.text I18n.l(Time.current, format: :long), size: 7, color: COLORS[:secondary], align: :right
          end
        end
      end

      def generate_qr_svg(url)
        RQRCode::QRCode.new(url).as_svg(
          module_size: 80,
          standalone: true,
          use_path: true
        )
      end

      def render_safe_image(pdf, attachment, width:)
        image_data = StringIO.new(attachment.download)
        pdf.image(image_data, width: width, position: :center)
        pdf.move_down 16
      rescue StandardError
        nil
      end
  end
end
