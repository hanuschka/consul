module PdfServices
  class DeficiencyReportExporter < PdfServices::BaseService
    def initialize(deficiency_report)
      @deficiency_report = deficiency_report
    end

    def call
      Prawn::Document.new(page_size: "A4", margin: 30) do |pdf|
        pdf.text @deficiency_report.title, size: 20, style: :bold

        pdf.move_down 10

        pdf.formatted_text [
          { text: "#{I18n.t("custom.admin.deficiency_reports.show.created_at")}: ", size: 10, styles: [:bold] },
          { text: @deficiency_report.created_at.strftime("%d %b %Y"), size: 10 }
        ]

        pdf.formatted_text [
          { text: "#{I18n.t("custom.admin.deficiency_reports.show.updated_at")}: ", size: 10, styles: [:bold] },
          { text: @deficiency_report.updated_at.strftime("%d %b %Y"), size: 10 }
        ]

        pdf.move_down 10

        if @deficiency_report.approximated_address.present?
          pdf.formatted_text [
            { text: "#{DeficiencyReport.human_attribute_name(:approximated_address)}: ", size: 10, styles: [:bold] },
            { text: @deficiency_report.approximated_address, size: 10 }
          ]
        end

        pdf.move_down 10

        if @deficiency_report.image.present?
          image_data = StringIO.open(@deficiency_report.image.attachment.download)
          pdf.image(image_data, width: 500)
        end

        pdf.move_down 20

        pdf.text html_to_paragraphs(@deficiency_report.description), size: 10, inline_format: true

        pdf.move_down 10

        pdf.text "#{DeficiencyReport.human_attribute_name(:author)}:", size: 10, style: :bold
        pdf.text @deficiency_report.author.username, size: 10
        pdf.text @deficiency_report.author.full_name, size: 10

        if @deficiency_report.on_behalf_of.present?
          pdf.text "(#{I18n.t("custom.admin.deficiency_reports.show.on_behalf_of")} #{@deficiency_report.on_behalf_of})", size: 10
        end

        pdf.move_down 10

        pdf.text "#{DeficiencyReport.human_attribute_name(:address)}:", size: 10, style: :bold
        pdf.text @deficiency_report.author.formatted_address, size: 10
        pdf.text @deficiency_report.author.plz.to_s, size: 10
        pdf.text @deficiency_report.author.city_name, size: 10
      end
    end
  end
end
