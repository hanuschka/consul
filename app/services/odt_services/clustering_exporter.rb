module OdtServices
  class ClusteringExporter
    def initialize(projekt_phase:, clustering_data:, clustering_type:)
      @projekt_phase = projekt_phase
      @clustering_data = clustering_data
      @clustering_type = clustering_type
    end

    def call
      text_content = generate_text_content
      convert_to_odt(text_content)
    end

    private

      def generate_text_content
        lines = []
        lines << title
        lines << ""
        lines << metadata
        lines << ""
        lines << categories_content
        lines.join("\n")
      end

      def title
        title_key = @clustering_type == :topic ? "pdf_title_topic" : "pdf_title_semantic"
        I18n.t("custom.ai_stats.clustering_export.#{title_key}")
      end

      def metadata
        projekt = @projekt_phase.projekt
        [
          "#{I18n.t('custom.ai_stats.clustering_export.pdf_projekt')}: #{projekt.title}",
          "#{I18n.t('custom.ai_stats.clustering_export.pdf_phase')}: #{@projekt_phase.title}",
          "#{I18n.t('custom.ai_stats.clustering_export.pdf_exported')}: #{Time.current.strftime('%d %b %Y %H:%M')}"
        ].join("\n")
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
        return @clustering_data if @clustering_data.is_a?(Hash)
        return { "categories" => @clustering_data } if @clustering_data.is_a?(Array)

        begin
          JSON.parse(@clustering_data)
        rescue JSON::ParserError, TypeError
          {}
        end
      end

      def category_content(category, index)
        category_name = category["name"]
        subcategories = category["subcategories"] || []
        resource_count = subcategories.sum { |s| (s["resource_ids"] || []).size }

        lines = []
        lines << "#{index + 1}. #{category_name}"
        lines << "   #{subcategories.size} #{I18n.t('custom.ai_stats.topic_clustering.subcategories')}, #{resource_count} #{I18n.t('custom.ai_stats.topic_clustering.resources')}"

        subcategories.each do |subcategory|
          subcategory_name = subcategory["name"]
          resource_ids = subcategory["resource_ids"] || []
          lines << "   • #{subcategory_name} (#{resource_ids.size})"
        end

        lines.join("\n")
      end

      def convert_to_odt(text_content)
        input_file = Tempfile.new(["clustering_export", ".txt"])
        output_file = Tempfile.new(["clustering_export", ".odt"])

        begin
          input_file.write(text_content)
          input_file.close

          system("pandoc", "-f", "plain", "-t", "odt", "-o", output_file.path, input_file.path)

          output_file.rewind
          output_file.read
        ensure
          input_file.unlink
          output_file.close
          output_file.unlink
        end
      end
  end
end
