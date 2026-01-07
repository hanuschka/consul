module PdfServices
  class StatQuestionExporter
    def initialize(stat_question)
      @stat_question = stat_question
    end

    def call
      Prawn::Document.new(page_size: "A4", margin: 30) do |pdf|
        pdf.text I18n.t("custom.participation_stats.ai_question.pdf_title"), size: 20, style: :bold
        pdf.move_down 10

        pdf.formatted_text [
          { text: "#{I18n.t('custom.participation_stats.ai_question.pdf_date')}: ", styles: [:bold] },
          { text: @stat_question.created_at.strftime("%d %b %Y %H:%M") }
        ]

        pdf.move_down 15
        pdf.text "#{I18n.t('custom.participation_stats.ai_question.pdf_question')}:", size: 14, style: :bold
        pdf.text @stat_question.question, size: 10

        pdf.move_down 15
        pdf.text "#{I18n.t('custom.participation_stats.ai_question.pdf_answer')}:", size: 14, style: :bold
        pdf.text @stat_question.answer.to_s, size: 10
      end
    end
  end
end
