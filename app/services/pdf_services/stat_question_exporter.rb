module PdfServices
  class StatQuestionExporter
    def initialize(stat_question)
      @stat_question = stat_question
    end

    def call
      Prawn::Document.new(page_size: "A4", margin: 30) do |pdf|
        pdf.text I18n.t("custom.participation_stats.ai_question.pdf_title"), size: 20, style: :bold
        pdf.move_down 10

        projekt_phase = @stat_question.projekt_phase
        projekt = projekt_phase.projekt

        pdf.formatted_text [
          { text: "#{I18n.t('custom.participation_stats.ai_question.pdf_projekt')}: ", styles: [:bold], size: 10 },
          { text: projekt.title, size: 10 }
        ]
        pdf.move_down 4

        pdf.formatted_text [
          { text: "#{I18n.t('custom.participation_stats.ai_question.pdf_phase')}: ", styles: [:bold], size: 10 },
          { text: projekt_phase.title, size: 10 }
        ]
        pdf.move_down 4

        pdf.formatted_text [
          { text: "#{I18n.t('custom.participation_stats.ai_question.pdf_date')}: ", styles: [:bold], size: 10 },
          { text: @stat_question.created_at.strftime("%d %b %Y %H:%M"), size: 10 }
        ]

        pdf.move_down 15
        pdf.text "#{I18n.t('custom.participation_stats.ai_question.pdf_question')}:", size: 14, style: :bold
        pdf.text @stat_question.question, size: 10

        pdf.move_down 15
        pdf.text "#{I18n.t('custom.participation_stats.ai_question.pdf_answer')}:", size: 14, style: :bold
        pdf.move_down 5
        render_html_content(pdf, @stat_question.answer.to_s)
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
