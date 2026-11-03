module PdfServices
  class DeficiencyReportManagementReportExporter < PdfServices::BaseService
    SCOPE = "adm.deficiency_reports.management_reports".freeze

    def initialize(management_report, host)
      @management_report = management_report
      @host = host
    end

    def call
      Prawn::Document.new(page_size: "A4", margin: [0, 18, 40, 18]) do |pdf|
        setup_fonts(pdf)
        render_header_banner(pdf, title_text: I18n.t("#{SCOPE}.show.title", name: @management_report.profile_name))
        pdf.indent(24, 24) do
          render_meta_card(pdf, meta_rows, timestamp: I18n.l(@management_report.generated_at || Time.current, format: :long))
          pdf.text I18n.t("#{SCOPE}.show.ai_notice"), size: 9, color: COLORS[:secondary], leading: 2
          pdf.move_down 16

          @management_report.building_blocks.each { |building_block| render_section(pdf, building_block) }
        end
        render_footer(pdf)
      end
    end

    private

      def meta_rows
        [
          [I18n.t("#{SCOPE}.show.period"), period_text],
          [I18n.t("#{SCOPE}.show.profile"), @management_report.profile_name]
        ]
      end

      def period_text
        "#{I18n.l(@management_report.period_start, format: :long)} – #{I18n.l(@management_report.period_end, format: :long)}"
      end

      def render_section(pdf, building_block)
        pdf.text I18n.t("#{SCOPE}.sections.#{building_block}"),
                 size: 12, style: :bold, color: COLORS[:accent]
        pdf.move_down 6

        rows = @management_report.figure_rows(building_block)
        if rows.any?
          rows.each do |row|
            pdf.formatted_text [
              { text: "#{figure_label(row)}:  ", size: 10, styles: [:bold], color: COLORS[:secondary] },
              { text: row[:value].to_s, size: 10, color: COLORS[:primary] }
            ]
          end
          pdf.move_down 6
        end

        @management_report.statements_for(building_block).each do |statement|
          pdf.text "• #{escape(statement["text"])}#{report_links(statement["report_ids"])}",
                   size: 10, color: COLORS[:primary], leading: 3, inline_format: true
          pdf.move_down 3
        end

        pdf.move_down 14
      end

      def figure_label(row)
        row[:report_id] ? "##{row[:report_id]} #{row[:label]}" : row[:label].to_s
      end

      def report_links(report_ids)
        return "" if report_ids.blank?

        links = report_ids.map do |id|
          url = adm_deficiency_reports_deficiency_report_url(id, host: @host)
          "<color rgb='#{COLORS[:accent]}'><link href='#{url}'><u>##{id}</u></link></color>"
        end

        " (#{links.join(", ")})"
      end

      def escape(text)
        text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
      end
  end
end
