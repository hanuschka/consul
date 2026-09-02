module PdfServices
  class DeficiencyReportExporter < PdfServices::BaseService
    def initialize(deficiency_report, host)
      @deficiency_report = deficiency_report
      @host = host
    end

    def call
      Prawn::Document.new(page_size: "A4", margin: [0, 18, 15, 18]) do |pdf|
        setup_fonts(pdf)
        render_header_banner(pdf, title_text: "#{@deficiency_report.title} (#{@deficiency_report.id})")
        pdf.indent(24, 24) do
          render_meta_card(pdf, meta_rows, qr_url: record_url, timestamp: I18n.l(Time.current, format: :long))
          render_description(pdf, @deficiency_report.description)

          render_image_and_map_stacked(
            pdf,
            @deficiency_report.image,
            @deficiency_report.map_location,
            image_max_height: 520
          )
          render_official_answer(pdf)
        end
      end
    end

    private

      def meta_rows
        scope = "adm.deficiency_reports.deficiency_reports.show"

        rows = [
          ["ID", @deficiency_report.id.to_s],
          [I18n.t("custom.admin.deficiency_reports.show.created_at"), I18n.l(@deficiency_report.created_at, format: :long)],
          [I18n.t("custom.admin.deficiency_reports.show.updated_at"), I18n.l(@deficiency_report.updated_at, format: :long)]
        ]

        if @deficiency_report.status.present?
          rows << [DeficiencyReport.human_attribute_name(:status), @deficiency_report.status.title]
        end

        if @deficiency_report.approximated_address.present?
          rows << [DeficiencyReport.human_attribute_name(:approximated_address), @deficiency_report.approximated_address]
        end

        if @deficiency_report.author.present?
          rows << [I18n.t("#{scope}.author"), @deficiency_report.author.username]
        end

        if @deficiency_report.on_behalf_of_differs_from_author?
          rows << [I18n.t("#{scope}.on_behalf_of_label"), @deficiency_report.on_behalf_of]
        end

        if @deficiency_report.on_behalf_of_account_linked?
          rows << [I18n.t("#{scope}.recorded_by_label"), @deficiency_report.recorded_by.username]
        end

        if @deficiency_report.category.present?
          rows << [I18n.t("#{scope}.category"), @deficiency_report.category.name]
        end

        if @deficiency_report.video_url.present?
          rows << [I18n.t("#{scope}.video_url"), @deficiency_report.video_url]
        end

        if @deficiency_report.documents.any?
          rows << [I18n.t("#{scope}.documents_label"), @deficiency_report.documents.map(&:title).join(", ")]
        end

        rows << ["Link", record_url]

        rows
      end

      def render_official_answer(pdf)
        body = html_to_paragraphs(@deficiency_report.official_answer.to_s)
        return unless body.present?

        pdf.text I18n.t("adm.deficiency_reports.deficiency_reports.show.official_answer"),
                 size: 12, style: :bold, color: COLORS[:accent]
        pdf.move_down 4
        pdf.text body, size: 10, color: COLORS[:primary], leading: 4, inline_format: true
        pdf.move_down 16
      end

      def record_url
        Rails.application.routes.url_helpers.deficiency_report_url(@deficiency_report, host: @host)
      end
  end
end
