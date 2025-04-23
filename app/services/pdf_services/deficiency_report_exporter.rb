module PdfServices
  class DeficiencyReportExporter < PdfServices::BaseService
    def initialize(deficiency_report, host)
      @deficiency_report = deficiency_report
      @host = host
    end

    def call
      Prawn::Document.new(page_size: "A4", margin: 30) do |pdf|
        pdf.text @deficiency_report.title, size: 20, style: :bold

        pdf.move_down 10

        pdf.formatted_text [
          { text: "ID: ", size: 10, styles: [:bold] },
          { text: @deficiency_report.id.to_s, size: 10 }
        ]

        pdf.formatted_text [
          { text: "#{I18n.t("custom.admin.deficiency_reports.show.created_at")}: ", size: 10, styles: [:bold] },
          { text: @deficiency_report.created_at.strftime("%d %b %Y"), size: 10 }
        ]

        pdf.formatted_text [
          { text: "#{I18n.t("custom.admin.deficiency_reports.show.updated_at")}: ", size: 10, styles: [:bold] },
          { text: @deficiency_report.updated_at.strftime("%d %b %Y"), size: 10 }
        ]

        pdf.move_down 10

        pdf.svg(svg, at: [pdf.bounds.left + 500 - 80, pdf.bounds.top - 30], width: 80)

        pdf.move_down 10

        if @deficiency_report.approximated_address.present?
          pdf.formatted_text [
            { text: "#{DeficiencyReport.human_attribute_name(:approximated_address)}: ", size: 10, styles: [:bold] },
            { text: @deficiency_report.approximated_address, size: 10 }
          ]
        end

        pdf.move_down 10

        pdf.formatted_text [
          { text: "#{I18n.t("custom.admin.deficiency_reports.show.link")}: ", size: 10, styles: [:bold] },
          { text: deficiency_report_url, size: 10, link: deficiency_report_url }
        ]

        pdf.move_down 10

        if @deficiency_report&.map_location&.screenshot.present?
          image_data = StringIO.open(@deficiency_report.map_location.screenshot.download)
          pdf.image(image_data, width: 500)
        end

        pdf.move_down 10

        if @deficiency_report.image.present?
          image_data = StringIO.open(@deficiency_report.image.attachment.download)
          pdf.image(image_data, width: 500)
        end

        pdf.move_down 20

        pdf.text html_to_paragraphs(@deficiency_report.description), size: 10, inline_format: true

        pdf.move_down 10
      end
    end

    private

      def deficiency_report_url
        Rails.application.routes.url_helpers.deficiency_report_url(@deficiency_report, host: @host)
      end

      def svg
        qrcode = RQRCode::QRCode.new(deficiency_report_url)

        qrcode.as_svg(
          module_size: 80,
          standalone: true,
          use_path: true
        )
      end
  end
end
