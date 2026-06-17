module DocxServices
  class ClusteringExporter
    def initialize(projekt_phase:, clustering_data:, clustering_type:, resource_class: nil)
      @projekt_phase = projekt_phase
      @clustering_data = clustering_data
      @clustering_type = clustering_type
      @resource_class = resource_class
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
        @working_copy_path ||= "/tmp/clustering_working_#{Time.current.to_i}_#{rand(10000)}.docx"
      end

      def output_path
        @output_path ||= "/tmp/clustering_export_#{Time.current.to_i}_#{rand(10000)}.docx"
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
        @relationship_id_counter = 1

        title_key = @clustering_type == :topic ? "pdf_title_topic" : "pdf_title_semantic"
        base_title = I18n.t("custom.ai_stats.clustering_export.#{title_key}")
        projekt_name = @projekt_phase.projekt.title

        add_heading("#{base_title} - #{projekt_name}", 1)
        add_horizontal_line

        add_paragraph("#{I18n.t('custom.ai_stats.clustering_export.pdf_projekt')}: #{@projekt_phase.projekt.title}")
        add_paragraph("#{I18n.t('custom.ai_stats.clustering_export.pdf_phase')}: #{@projekt_phase.title}")
        add_paragraph("#{I18n.t('custom.ai_stats.clustering_export.pdf_exported')}: #{Time.current.strftime('%d.%m.%Y %H:%M')}")
        add_horizontal_line

        add_summary
        add_horizontal_line

        add_categories
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

      def add_summary
        data = parse_clustering_data
        categories = data["categories"] || []
        total_resources = categories.sum { |c|
          (c["subtopics"] || c["subcategories"] || []).sum { |s| get_resource_ids(s).size }
        }

        text = "#{categories.size} #{I18n.t('custom.ai_stats.topic_clustering.category_groups')}    #{total_resources} #{I18n.t('custom.ai_stats.topic_clustering.resources')}"
        add_paragraph(text, bold: true)
      end

      def add_categories
        data = parse_clustering_data
        categories = data["categories"] || []

        categories.each_with_index do |category, index|
          add_category(category, index)
        end
      end

      def add_category(category, index)
        category_name = category["name"]
        subcategories = category["subtopics"] || category["subcategories"] || []
        resource_count = subcategories.sum { |s| get_resource_ids(s).size }

        add_heading("#{index + 1}. #{category_name}", 2)
        add_paragraph("#{subcategories.size} #{I18n.t('custom.ai_stats.topic_clustering.subcategories')} • #{resource_count} #{I18n.t('custom.ai_stats.topic_clustering.resources')}")

        subcategories.each do |subcategory|
          add_subcategory(subcategory)
        end
      end

      def add_subcategory(subcategory)
        subcategory_name = subcategory["name"]
        resource_ids = get_resource_ids(subcategory)

        add_heading("#{subcategory_name} (#{resource_ids.size})", 3)

        if @resource_class.present? && resource_ids.any?
          resources = fetch_resources(resource_ids)
          resources.each do |resource|
            add_resource(resource)
          end
        end
      end

      def add_resource(resource)
        title = resource_title(resource)
        url = resource_url(resource)
        author_url = author_profile_url(resource)
        author_name = author_full_name(resource)

        add_paragraph(title, bold: true)

        if url.present?
          add_hyperlink(url)
        end

        if author_url.present?
          add_author_link(author_url, author_name)
        end
      end

      def add_hyperlink(url)
        rel_id = "rId#{@relationship_id_counter}"
        @relationship_id_counter += 1

        add_hyperlink_relationship(rel_id, url)

        p_node = @templates[:indent].dup
        p_node.xpath('.//w:r').remove

        hyperlink = @doc.doc.create_element('w:hyperlink')
        hyperlink['r:id'] = rel_id

        r_node = @doc.doc.create_element('w:r')
        rPr = r_node.add_child(@doc.doc.create_element('w:rPr'))
        rPr.add_child(@doc.doc.create_element('w:rStyle')).tap { |s| s['w:val'] = 'Hyperlink' }
        color = rPr.add_child(@doc.doc.create_element('w:color'))
        color['w:val'] = '0563C1'
        rPr.add_child(@doc.doc.create_element('w:u')).tap { |u| u['w:val'] = 'single' }

        t_node = r_node.add_child(@doc.doc.create_element('w:t'))
        t_node['xml:space'] = 'preserve'
        t_node.content = url

        hyperlink.add_child(r_node)
        p_node.add_child(hyperlink)

        @body.add_child(p_node)
      end

      def add_author_link(author_url, author_name)
        rel_id = "rId#{@relationship_id_counter}"
        @relationship_id_counter += 1

        add_hyperlink_relationship(rel_id, author_url)

        p_node = @templates[:indent].dup
        p_node.xpath('.//w:r').remove

        hyperlink = @doc.doc.create_element('w:hyperlink')
        hyperlink['r:id'] = rel_id

        r_node = @doc.doc.create_element('w:r')
        rPr = r_node.add_child(@doc.doc.create_element('w:rPr'))
        rPr.add_child(@doc.doc.create_element('w:rStyle')).tap { |s| s['w:val'] = 'Hyperlink' }
        color = rPr.add_child(@doc.doc.create_element('w:color'))
        color['w:val'] = '0563C1'
        rPr.add_child(@doc.doc.create_element('w:u')).tap { |u| u['w:val'] = 'single' }

        t_node = r_node.add_child(@doc.doc.create_element('w:t'))
        t_node['xml:space'] = 'preserve'
        t_node.content = author_name

        hyperlink.add_child(r_node)
        p_node.add_child(hyperlink)

        @body.add_child(p_node)
      end

      def add_hyperlink_relationship(rel_id, url)
        rels_file = @doc.doc.at_xpath('//xmlns:Relationships', 'xmlns' => 'http://schemas.openxmlformats.org/package/2006/relationships')

        unless rels_file
          rels_doc = @doc.instance_variable_get(:@zip).find_entry('word/_rels/document.xml.rels')
          if rels_doc
            rels_content = rels_doc.get_input_stream.read
            rels_xml = Nokogiri::XML(rels_content)
            rels_file = rels_xml.at_xpath('//xmlns:Relationships', 'xmlns' => 'http://schemas.openxmlformats.org/package/2006/relationships')
          end
        end

        if rels_file
          relationship = Nokogiri::XML::Node.new('Relationship', rels_file.document)
          relationship['Id'] = rel_id
          relationship['Type'] = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink'
          relationship['Target'] = url
          relationship['TargetMode'] = 'External'
          rels_file.add_child(relationship)

          @doc.instance_variable_get(:@zip).get_output_stream('word/_rels/document.xml.rels') do |f|
            f.write(rels_file.document.to_xml)
          end
        end
      end

      def parse_clustering_data
        return {} if @clustering_data.nil?

        if @clustering_data.is_a?(Array)
          return { "categories" => @clustering_data }
        elsif @clustering_data.is_a?(Hash)
          return @clustering_data if @clustering_data["categories"].present?
          return { "categories" => @clustering_data.values } if @clustering_data.any?
          return {}
        end

        begin
          parsed = JSON.parse(@clustering_data)
          return { "categories" => parsed } if parsed.is_a?(Array)
          parsed
        rescue JSON::ParserError, TypeError
          {}
        end
      end

      def get_resource_ids(subcategory)
        subcategory["resource_ids"] || subcategory["proposal_ids"] || []
      end

      def fetch_resources(ids)
        return [] if ids.blank? || @resource_class.nil?

        @resource_class.where(id: ids)
      end

      def resource_title(resource)
        if resource.respond_to?(:title)
          resource.title
        elsif resource.respond_to?(:body)
          resource.body.to_s.truncate(100)
        else
          resource.id.to_s
        end
      end

      def resource_url(resource)
        Rails.application.routes.url_helpers.polymorphic_url(
          resource,
          **UrlOptions.default
        )
      rescue StandardError
        nil
      end

      def author_profile_url(resource)
        return nil unless resource.respond_to?(:author) && resource.author.present?

        Rails.application.routes.url_helpers.user_url(
          resource.author,
          **UrlOptions.default
        )
      rescue StandardError
        nil
      end

      def author_full_name(resource)
        return nil unless resource.respond_to?(:author) && resource.author.present?

        author = resource.author
        if author.respond_to?(:name) && author.name.present?
          author.name
        elsif author.respond_to?(:username)
          author.username
        end
      end

      def strip_html(text)
        ActionView::Base.full_sanitizer.sanitize(text).squish
      end
  end
end
