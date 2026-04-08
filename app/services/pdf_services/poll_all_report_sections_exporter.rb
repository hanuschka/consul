module PdfServices
  class PollAllReportSectionsExporter
    def initialize(poll, reports)
      @poll = poll
      @reports = reports
    end

    def call
      Prawn::Document.new(page_size: "A4", margin: 45) do |pdf|
        pdf.text I18n.t("custom.polls.report.title"), size: 20, style: :bold
        pdf.move_down 10

        pdf.formatted_text [
          { text: "#{I18n.t('activerecord.models.poll.one')}: ", styles: [:bold], size: 10 },
          { text: @poll.name, size: 10 }
        ]
        pdf.move_down 4

        pdf.formatted_text [
          { text: "#{I18n.t('custom.participation_stats.ai_question.pdf_date')}: ", styles: [:bold], size: 10 },
          { text: Time.zone.now.strftime("%d %b %Y %H:%M"), size: 10 }
        ]
        pdf.move_down 20

        @reports.each_with_index do |report, index|
          pdf.start_new_page if index > 0

          pdf.text report["title"], size: 14, style: :bold
          pdf.move_down 10
          render_html_content(pdf, report["content"].to_s)
        end
      end
    end

    private

    def render_html_content(pdf, html_content)
      doc = Nokogiri::HTML.fragment(html_content)

      doc.children.each do |node|
        case node.name
        when "h3", "h4"
          pdf.move_down 10
          pdf.text node.text.strip, size: 12, style: :bold
          pdf.move_down 5
        when "p"
          pdf.text node.text.strip, size: 10
          pdf.move_down 5
        when "ul"
          render_list(pdf, node)
        when "text"
          text_content = node.text.strip
          pdf.text text_content, size: 10 unless text_content.empty?
        end
      end
    end

    def render_list(pdf, ul_node)
      ul_node.css("li").each do |li|
        pdf.text "• #{li.text.strip}", size: 10, indent_paragraphs: 0
      end
      pdf.move_down 5
    end
  end
end
