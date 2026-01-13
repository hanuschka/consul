module PdfServices
  class AllStatQuestionsExporter
    def initialize(projekt_phase)
      @projekt_phase = projekt_phase
    end

    def call
      Prawn::Document.new(page_size: "A4", margin: 45) do |pdf|
        pdf.text I18n.t("custom.participation_stats.ai_question.pdf_all_questions_title"), size: 20, style: :bold
        pdf.move_down 10

        projekt = @projekt_phase.projekt

        pdf.formatted_text [
          { text: "#{I18n.t('custom.participation_stats.ai_question.pdf_projekt')}: ", styles: [:bold], size: 10 },
          { text: projekt.title, size: 10 }
        ]
        pdf.move_down 4

        pdf.formatted_text [
          { text: "#{I18n.t('custom.participation_stats.ai_question.pdf_phase')}: ", styles: [:bold], size: 10 },
          { text: @projekt_phase.title, size: 10 }
        ]
        pdf.move_down 4

        pdf.formatted_text [
          { text: "#{I18n.t('custom.participation_stats.ai_question.pdf_exported_at')}: ", styles: [:bold], size: 10 },
          { text: Time.current.strftime("%d %b %Y %H:%M"), size: 10 }
        ]

        pdf.move_down 20

        stat_questions = @projekt_phase.stat_questions.answered.by_newest

        if stat_questions.any?
          stat_questions.each_with_index do |stat_question, index|
            render_question(pdf, stat_question, index)
            pdf.start_new_page if index < stat_questions.count - 1
          end
        else
          pdf.text I18n.t("custom.participation_stats.ai_question.pdf_no_questions"), size: 12, style: :italic
        end
      end
    end

    private

    def render_question(pdf, stat_question, index)
      pdf.formatted_text [
        { text: "#{I18n.t('custom.participation_stats.ai_question.pdf_question')} #{index + 1}:", size: 14, styles: [:bold] }
      ]
      pdf.move_down 10

      pdf.text stat_question.question, size: 10
      pdf.move_down 10

      pdf.text "#{I18n.t('custom.participation_stats.ai_question.pdf_answer')}:", size: 12, style: :bold
      pdf.move_down 5

      render_html_content(pdf, stat_question.answer.to_s)

      pdf.move_down 10
      pdf.formatted_text [
        { text: "#{I18n.t('custom.participation_stats.ai_question.pdf_date')}: ", styles: [:bold], size: 9 },
        { text: stat_question.created_at.strftime("%d %b %Y %H:%M"), size: 9 }
      ]
    end

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
