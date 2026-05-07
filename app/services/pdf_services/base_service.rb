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
        fonts_dir = Rails.root.join("app/assets/fonts/custom")
        pdf.font_families.update("Asap" => {
          normal: fonts_dir.join("Asap-Regular.ttf"),
          bold: fonts_dir.join("Asap-Bold.ttf"),
          italic: fonts_dir.join("Asap-Italic.ttf"),
          bold_italic: fonts_dir.join("Asap-BoldItalic.ttf")
        })
        pdf.font "Asap"
      end

      def render_header_banner(pdf, title_text:, qr_url: nil)
        banner_height = 65
        qr_size = 36
        title_size = 18
        title_box_height = 22
        title_top_padding = 22

        pdf.canvas do
          pdf.fill_color COLORS[:header_bg]
          pdf.fill_rectangle([0, pdf.bounds.top], pdf.bounds.width, banner_height)
        end

        if qr_url
          qr_y = pdf.bounds.top - (banner_height - qr_size) / 2
          pdf.fill_color COLORS[:white]
          pdf.fill_rounded_rectangle([pdf.bounds.width - 40 - qr_size - 4, qr_y + 4], qr_size + 8, qr_size + 8, 3)
          pdf.svg(generate_qr_svg(qr_url), at: [pdf.bounds.width - 40 - qr_size, qr_y], width: qr_size)
          title_width = pdf.bounds.width - 10 - qr_size - 24
        else
          title_width = pdf.bounds.width - 10
        end

        title_y = pdf.bounds.top - title_top_padding
        pdf.bounding_box([20, title_y], width: title_width, height: title_box_height) do
          pdf.text title_text, size: title_size, style: :bold, color: COLORS[:header_text], overflow: :shrink_to_fit, valign: :center
        end

        pdf.fill_color COLORS[:primary]
        pdf.move_cursor_to pdf.bounds.top - banner_height - 12
      end

      def render_meta_card(pdf, rows, qr_url: nil, timestamp: nil)
        card_padding = 8
        row_spacing = 2
        qr_size = 84
        qr_gap = 12
        ts_height = 10
        ts_gap = 10

        text_inner_width =
          if qr_url || timestamp
            pdf.bounds.width - 8 - qr_size - qr_gap
          else
            pdf.bounds.width - 8
          end

        text_height = rows.sum do |label, value|
          line = "#{label}:  #{value}"
          pdf.height_of(line, size: 10, width: text_inner_width) + row_spacing
        end

        right_height = 0
        right_height += ts_height if timestamp
        right_height += ts_gap if timestamp && qr_url
        right_height += qr_size if qr_url

        content_height = [text_height, right_height].max
        card_height = content_height + card_padding * 2
        start_y = pdf.cursor

        pdf.fill_color COLORS[:card_bg]
        pdf.fill_rounded_rectangle([0, start_y], pdf.bounds.width, card_height, 4)
        pdf.fill_color COLORS[:primary]

        pdf.stroke_color COLORS[:border]
        pdf.rounded_rectangle([0, start_y], pdf.bounds.width, card_height, 4)
        pdf.stroke

        pdf.bounding_box([14, start_y - card_padding], width: text_inner_width, height: card_height - card_padding * 2) do
          rows.each do |label, value|
            pdf.formatted_text [
              { text: "#{label}:  ", size: 10, styles: [:bold], color: COLORS[:secondary] },
              { text: value.to_s, size: 10, color: COLORS[:primary] }
            ]
            pdf.move_down row_spacing
          end
        end

        right_x = pdf.bounds.width - card_padding - qr_size
        right_top_y = start_y - card_padding

        if timestamp
          pdf.text_box timestamp,
                       at: [right_x, right_top_y],
                       width: qr_size,
                       height: ts_height,
                       align: :right,
                       size: 8,
                       overflow: :shrink_to_fit,
                       valign: :top,
                       inline_format: false,
                       color: COLORS[:secondary]
        end

        if qr_url
          qr_y = right_top_y
          qr_y -= ts_height + ts_gap if timestamp
          pdf.svg(generate_qr_svg(qr_url), at: [right_x, qr_y], width: qr_size)
        end

        pdf.move_cursor_to(start_y - card_height - 12)
      end

      def render_title_and_description(pdf, title:, description_html:)
        pdf.text title, size: 14, style: :bold, color: COLORS[:accent]
        pdf.move_down 6

        render_description(pdf, description_html)
      end

      def render_description(pdf, description_html)
        description = html_to_paragraphs(description_html)
        return unless description.present?

        pdf.text description, size: 10, color: COLORS[:primary], leading: 4, inline_format: true
        pdf.move_down 6
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

      def render_map_image(pdf, map_location, width: nil)
        return unless map_location&.screenshot.present?

        render_safe_image(pdf, map_location.screenshot, width: width || pdf.bounds.width)
      end

      def render_attachment_image(pdf, image, width: nil)
        return unless image&.attachment&.attached?

        bytes = pdf_variant_bytes(image) || image.attachment.download
        pdf.image(StringIO.new(bytes), width: width || [pdf.bounds.width, 360].min, position: :center)
        pdf.move_down 16
      rescue StandardError
        nil
      end

      def pdf_variant_bytes(image)
        variant = image.variant(:pdf)
        return nil unless variant.respond_to?(:processed)

        variant.processed.download
      rescue StandardError
        nil
      end

      def render_image_and_map_side_by_side(pdf, image, map_location, image_max_height: 360, map_max_height: 360, both_scale: 0.7, gap: 12, bottom_padding: 16, max_total_height: nil)
        image_bytes = nil
        if image&.attachment&.attached?
          image_bytes = pdf_variant_bytes(image) || safe_download(image.attachment)
        end

        map_bytes = nil
        if map_location&.screenshot.present?
          map_bytes = safe_download(map_location.screenshot)
        end

        return if image_bytes.blank? && map_bytes.blank?

        if image_bytes.present? && map_bytes.present?
          image_h = image_max_height * both_scale
          map_h = map_max_height * both_scale

          if max_total_height
            available = max_total_height - gap
            wanted = image_h + map_h
            if wanted > available && available > 0
              ratio = available / wanted.to_f
              image_h *= ratio
              map_h *= ratio
            end
          end

          scaled_width = pdf.bounds.width * both_scale
          render_single_image_row(pdf, image_bytes, image_h, max_width: scaled_width)
          pdf.move_down gap
          render_single_image_row(pdf, map_bytes, map_h, max_width: scaled_width)
        elsif image_bytes.present?
          h = max_total_height ? [image_max_height, max_total_height].min : image_max_height
          render_single_image_row(pdf, image_bytes, h)
        else
          h = max_total_height ? [map_max_height, max_total_height].min : map_max_height
          render_single_image_row(pdf, map_bytes, h)
        end

        pdf.move_down bottom_padding
      end

      def render_two_column_row(pdf, image_bytes, map_bytes, image_max_height, map_max_height, gutter)
        column_width = (pdf.bounds.width - gutter) / 2
        row_height = [image_max_height, map_max_height].max
        start_y = pdf.cursor

        if start_y - row_height < pdf.bounds.absolute_bottom - pdf.bounds.top
          pdf.start_new_page
          start_y = pdf.cursor
        end

        pdf.bounding_box([0, start_y], width: column_width, height: row_height) do
          render_fitted_image(pdf, image_bytes, column_width, image_max_height)
        end

        pdf.bounding_box([column_width + gutter, start_y], width: column_width, height: row_height) do
          render_fitted_image(pdf, map_bytes, column_width, map_max_height)
        end

        pdf.move_cursor_to(start_y - row_height)
      end

      def render_single_image_row(pdf, bytes, max_height, max_width: nil)
        io = StringIO.new(bytes)
        fit_width = max_width || pdf.bounds.width

        begin
          pdf.image(io, fit: [fit_width, max_height], position: :center)
        rescue Prawn::Errors::CannotFit
          pdf.start_new_page
          io.rewind
          pdf.image(io, fit: [fit_width, max_height], position: :center)
        end
      rescue StandardError
        nil
      end

      def render_fitted_image(pdf, bytes, width, height)
        return if bytes.blank?

        pdf.image(StringIO.new(bytes), fit: [width, height], position: :center, vposition: :center)
      rescue StandardError
        nil
      end

      def safe_download(attachment)
        attachment.download
      rescue StandardError
        nil
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
