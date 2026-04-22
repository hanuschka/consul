module PdfServices
  class DeficiencyReportExporter < PdfServices::BaseService
    def initialize(deficiency_report, host)
      @deficiency_report = deficiency_report
      @host = host
    end

    def call
      Prawn::Document.new(page_size: "A4", margin: [0, 0, 30, 0]) do |pdf|
        setup_fonts(pdf)
        render_header_banner(pdf, title_text: "#{@deficiency_report.title} (#{@deficiency_report.id})", qr_url: record_url)
        pdf.bounding_box([40, pdf.cursor], width: pdf.bounds.width - 80) do
          render_meta_card(pdf, meta_rows)
          render_title_and_description(pdf, title: @deficiency_report.title, description_html: @deficiency_report.description)
          render_map_image(pdf, @deficiency_report.map_location)
          render_attachment_image(pdf, @deficiency_report.image)
        end
        render_footer(pdf)
      end
    end

    private

      def meta_rows
        created_label = I18n.t("custom.admin.deficiency_reports.show.created_at")
        updated_label = I18n.t("custom.admin.deficiency_reports.show.updated_at")

        rows = [
          ["ID", @deficiency_report.id.to_s],
          [created_label, I18n.l(@deficiency_report.created_at, format: :long)],
          [updated_label, I18n.l(@deficiency_report.updated_at, format: :long)]
        ]

        if @deficiency_report.status.present?
          rows << [DeficiencyReport.human_attribute_name(:status), @deficiency_report.status.title]
        end

        if @deficiency_report.approximated_address.present?
          rows << [DeficiencyReport.human_attribute_name(:approximated_address), @deficiency_report.approximated_address]
        end

        rows << ["Link", record_url]

        rows
      end

      def record_url
        Rails.application.routes.url_helpers.deficiency_report_url(@deficiency_report, host: @host)
      end
  end
end
