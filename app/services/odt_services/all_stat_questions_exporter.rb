module OdtServices
  class AllStatQuestionsExporter
    def initialize(projekt_phase)
      @projekt_phase = projekt_phase
    end

    def call
      text_content = generate_text_content
      convert_to_odt(text_content)
    end

    private

      def generate_text_content
        lines = []
        title = I18n.t('custom.participation_stats.ai_question.pdf_all_questions_title')
        lines << "## #{title}"
        lines << ""
        lines << metadata
        lines << ""
        lines << "---"
        lines << ""

        stat_questions = @projekt_phase.stat_questions.answered.by_newest

        if stat_questions.any?
          stat_questions.each_with_index do |question, index|
            lines << question_content(question, index)
            lines << ""
            lines << "---"
            lines << ""
          end
        else
          lines << I18n.t('custom.participation_stats.ai_question.pdf_no_questions')
        end

        lines.join("\n")
      end

      def metadata
        projekt = @projekt_phase.projekt
        [
          "#{I18n.t('custom.participation_stats.ai_question.pdf_projekt')}: #{projekt.title}",
          "#{I18n.t('custom.participation_stats.ai_question.pdf_phase')}: #{@projekt_phase.title}",
          "#{I18n.t('custom.participation_stats.ai_question.pdf_exported_at')}: #{Time.current.strftime('%d.%m.%Y %H:%M')}"
        ].join("  \n")
      end

      def question_content(question, index)
        lines = []
        lines << "### #{I18n.t('custom.participation_stats.ai_question.pdf_question')} #{index + 1}"
        lines << ""
        lines << question.question
        lines << ""
        lines << "**#{I18n.t('custom.participation_stats.ai_question.pdf_answer')}:**"
        lines << ""
        lines << convert_html_to_markdown(question.answer.to_s)
        lines << ""
        lines << "_#{I18n.t('custom.participation_stats.ai_question.pdf_date')}: #{question.created_at.strftime('%d.%m.%Y %H:%M')}_"
        lines.join("\n")
      end

      def convert_html_to_markdown(html_content)
        doc_fragment = Nokogiri::HTML.fragment(html_content)
        lines = []

        doc_fragment.children.each do |node|
          case node.name
          when 'h3', 'h4'
            lines << "**#{node.text.strip}**"
          when 'p'
            lines << node.text.strip
          when 'ul'
            node.css('li').each do |li|
              lines << "- #{li.text.strip}"
            end
          when 'text'
            text_content = node.text.strip
            lines << text_content unless text_content.empty?
          end
        end

        lines.join("\n")
      end

      def convert_to_odt(text_content)
        raise "Cannot generate ODT from empty content" if text_content.blank?

        input_file = Tempfile.new(["stat_questions_export", ".txt"])
        output_file = Tempfile.new(["stat_questions_export", ".odt"], binmode: true)

        begin
          input_file.write(text_content)
          input_file.close

          success = system("pandoc", "-f", "markdown", "-t", "odt", "-V", "mainfont=Arial", "-o", output_file.path, input_file.path)

          unless success
            raise "Pandoc conversion failed. Please ensure pandoc is installed."
          end

          output_file.rewind
          content = output_file.read

          raise "Pandoc generated empty ODT file" if content.empty?

          content
        ensure
          input_file.unlink
          output_file.close
          output_file.unlink
        end
      end
  end
end
