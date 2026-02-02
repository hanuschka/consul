module OdtServices
  class ClusteringExporter
    def initialize(projekt_phase:, clustering_data:, clustering_type:, resource_class: nil)
      @projekt_phase = projekt_phase
      @clustering_data = clustering_data
      @clustering_type = clustering_type
      @resource_class = resource_class
    end

    def call
      text_content = generate_text_content
      convert_to_odt(text_content)
    end

    private

      def generate_text_content
        lines = []
        lines << "## #{title}"
        lines << ""
        lines << metadata
        lines << ""
        lines << "---"
        lines << ""
        lines << summary
        lines << ""
        lines << "---"
        lines << ""
        lines << categories_content
        lines.join("\n")
      end

      def title
        title_key = @clustering_type == :topic ? "pdf_title_topic" : "pdf_title_semantic"
        base_title = I18n.t("custom.ai_stats.clustering_export.#{title_key}")
        projekt_name = @projekt_phase.projekt.title
        "#{base_title} - #{projekt_name}"
      end

      def summary
        data = parse_clustering_data
        categories = data["categories"] || []
        total_resources = categories.sum { |c|
          (c["subtopics"] || c["subcategories"] || []).sum { |s| get_resource_ids(s).size }
        }

        [
          "#{categories.size} #{I18n.t('custom.ai_stats.topic_clustering.category_groups')}    #{total_resources} #{I18n.t('custom.ai_stats.topic_clustering.resources')}"
        ].join("\n")
      end

      def metadata
        projekt = @projekt_phase.projekt
        [
          "#{I18n.t('custom.ai_stats.clustering_export.pdf_projekt')}: #{projekt.title}",
          "#{I18n.t('custom.ai_stats.clustering_export.pdf_phase')}: #{@projekt_phase.title}",
          "#{I18n.t('custom.ai_stats.clustering_export.pdf_exported')}: #{Time.current.strftime('%d.%m.%Y %H:%M')}"
        ].join("  \n")
      end

      def categories_content
        data = parse_clustering_data
        categories = data["categories"] || []
        lines = []

        categories.each_with_index do |category, index|
          lines << ""
          lines << category_content(category, index)
        end

        lines.join("\n")
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

      def category_content(category, index)
        category_name = category["name"]
        subcategories = category["subtopics"] || category["subcategories"] || []
        resource_count = subcategories.sum { |s| get_resource_ids(s).size }

        lines = []
        lines << "## #{index + 1}. #{category_name}"
        lines << ""
        lines << "#{subcategories.size} #{I18n.t('custom.ai_stats.topic_clustering.subcategories')} • #{resource_count} #{I18n.t('custom.ai_stats.topic_clustering.resources')}"
        lines << ""

        subcategories.each do |subcategory|
          lines << subcategory_content(subcategory)
          lines << ""
        end

        lines.join("\n")
      end

      def subcategory_content(subcategory)
        subcategory_name = subcategory["name"]
        resource_ids = get_resource_ids(subcategory)
        lines = []

        lines << "### #{subcategory_name} (#{resource_ids.size})"
        lines << ""

        if @resource_class.present? && resource_ids.any?
          resources = fetch_resources(resource_ids)
          resources.each do |resource|
            lines << resource_content(resource)
          end
        end

        lines.join("\n")
      end

      def get_resource_ids(subcategory)
        subcategory["resource_ids"] || subcategory["proposal_ids"] || []
      end

      def fetch_resources(ids)
        return [] if ids.blank? || @resource_class.nil?

        @resource_class.where(id: ids)
      end

      def resource_content(resource)
        title = resource_title(resource)
        url = resource_url(resource)

        lines = []

        lines << "**#{title}**"

        if url.present?
          lines << ""
          lines << url
        end

        lines << ""
        lines.join("\n")
      end

      def resource_url(resource)
        Rails.application.routes.url_helpers.polymorphic_url(
          resource,
          host: Rails.application.config.action_mailer.default_url_options[:host] || "localhost:3000"
        )
      rescue StandardError
        nil
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

      def resource_details(resource)
        details = []

        if resource.respond_to?(:description) && resource.description.present?
          details << strip_html(resource.description.to_s).truncate(200)
        elsif resource.respond_to?(:body) && resource.body.present?
          details << strip_html(resource.body.to_s).truncate(200)
        end

        if resource.respond_to?(:author) && resource.author.present?
          details << "Autor: #{resource.author.username}"
        end

        details.join(" | ")
      end

      def strip_html(text)
        ActionView::Base.full_sanitizer.sanitize(text).squish
      end

      def convert_to_odt(text_content)
        raise "Cannot generate ODT from empty content" if text_content.blank?

        input_file = Tempfile.new(["clustering_export", ".txt"])
        output_file = Tempfile.new(["clustering_export", ".odt"], binmode: true)

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
