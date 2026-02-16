module DocxServices
  class AllStatQuestionsExporter
    def initialize(projekt_phase)
      @projekt_phase = projekt_phase
    end

    def call
      require 'docx'

      FileUtils.cp(static_template_path, working_copy_path)
      doc = Docx::Document.open(working_copy_path)

      build_document(doc)

      doc.save(output_path)
      File.binread(output_path)
    ensure
      File.unlink(working_copy_path) if working_copy_path && File.exist?(working_copy_path)
      File.unlink(output_path) if output_path && File.exist?(output_path)
    end

    private

      def static_template_path
        Rails.root.join('lib', 'templates', 'clustering_export_template.docx').to_s
      end

      def working_copy_path
        @working_copy_path ||= "/tmp/stat_questions_working_#{Time.current.to_i}_#{rand(10000)}.docx"
      end

      def output_path
        @output_path ||= "/tmp/stat_questions_export_#{Time.current.to_i}_#{rand(10000)}.docx"
      end

      def build_document(doc)
        @doc = doc
        @templates = {
          heading1: doc.paragraphs[0].node,
          heading2: doc.paragraphs[1].node,
          heading3: doc.paragraphs[2].node,
          normal: doc.paragraphs[3].node,
          bold: doc.paragraphs[4].node,
          indent: doc.paragraphs[5].node,
          line: doc.paragraphs[6].node
        }

        @body = doc.doc.at_xpath('//w:body')
        @body.children.remove

        title = I18n.t('custom.participation_stats.ai_question.pdf_all_questions_title')
        add_heading(title, 1)
        add_horizontal_line

        add_paragraph("#{I18n.t('custom.participation_stats.ai_question.pdf_projekt')}: #{@projekt_phase.projekt.title}")
        add_paragraph("#{I18n.t('custom.participation_stats.ai_question.pdf_phase')}: #{@projekt_phase.title}")
        add_paragraph("#{I18n.t('custom.participation_stats.ai_question.pdf_exported_at')}: #{Time.current.strftime('%d.%m.%Y %H:%M')}")
        add_horizontal_line

        add_questions
      end

      def add_heading(text, level)
        template_key = "heading#{level}".to_sym
        p_node = @templates[template_key].dup
        t_node = p_node.at_xpath('.//w:t')
        t_node.content = text
        @body.add_child(p_node)
      end

      def add_paragraph(text, bold: false, indent: false)
        template_key = if indent
          :indent
        elsif bold
          :bold
        else
          :normal
        end

        p_node = @templates[template_key].dup
        t_node = p_node.at_xpath('.//w:t')
        t_node.content = text
        @body.add_child(p_node)
      end

      def add_horizontal_line
        p_node = @templates[:line].dup
        @body.add_child(p_node)
      end

      def add_questions
        stat_questions = @projekt_phase.stat_questions.answered.by_newest

        if stat_questions.any?
          stat_questions.each_with_index do |question, index|
            add_question(question, index)
          end
        else
          add_paragraph(I18n.t('custom.participation_stats.ai_question.pdf_no_questions'))
        end
      end

      def add_question(question, index)
        add_paragraph("")
        add_heading("#{I18n.t('custom.participation_stats.ai_question.pdf_question')} #{index + 1}", 2)

        add_paragraph(question.question)
        add_paragraph("")

        add_paragraph(I18n.t('custom.participation_stats.ai_question.pdf_answer'), bold: true)
        add_paragraph("")

        add_answer_content(question.answer.to_s)

        add_paragraph("")
        add_paragraph("#{I18n.t('custom.participation_stats.ai_question.pdf_date')}: #{question.created_at.strftime('%d.%m.%Y %H:%M')}")
        add_horizontal_line
      end

      def add_answer_content(html_content)
        doc_fragment = Nokogiri::HTML.fragment(html_content)

        doc_fragment.children.each do |node|
          case node.name
          when 'h3', 'h4'
            add_paragraph(node.text.strip, bold: true)
          when 'p'
            add_paragraph(node.text.strip)
          when 'ul'
            add_list_items(node)
          when 'text'
            text_content = node.text.strip
            add_paragraph(text_content) unless text_content.empty?
          end
        end
      end

      def add_list_items(ul_node)
        ul_node.css('li').each do |li|
          add_paragraph("• #{li.text.strip}", indent: true)
        end
      end
  end
end
