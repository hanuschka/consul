module PdfServices
  class ClusteringExporter
    def initialize(projekt_phase:, clustering_data:, clustering_type:)
      @projekt_phase = projekt_phase
      @clustering_data = clustering_data
      @clustering_type = clustering_type
    end

    def call
      Prawn::Document.new(page_size: "A4", margin: 45) do |pdf|
        render_header(pdf)
        render_metadata(pdf)
        render_categories(pdf)
      end
    end

    private

      def render_header(pdf)
        title_key = @clustering_type == :topic ? "pdf_title_topic" : "pdf_title_semantic"
        pdf.text I18n.t("custom.ai_stats.clustering_export.#{title_key}"), size: 20, style: :bold
        pdf.move_down 10
      end

      def render_metadata(pdf)
        projekt = @projekt_phase.projekt

        pdf.formatted_text [
          { text: "#{I18n.t('custom.ai_stats.clustering_export.pdf_projekt')}: ", styles: [:bold], size: 10 },
          { text: projekt.title, size: 10 }
        ]
        pdf.move_down 4

        pdf.formatted_text [
          { text: "#{I18n.t('custom.ai_stats.clustering_export.pdf_phase')}: ", styles: [:bold], size: 10 },
          { text: @projekt_phase.title, size: 10 }
        ]
        pdf.move_down 4

        pdf.formatted_text [
          { text: "#{I18n.t('custom.ai_stats.clustering_export.pdf_exported')}: ", styles: [:bold], size: 10 },
          { text: Time.current.strftime("%d %b %Y %H:%M"), size: 10 }
        ]
        pdf.move_down 20
      end

      def render_categories(pdf)
        data = parse_clustering_data
        categories = data["categories"] || []

        categories.each_with_index do |category, index|
          render_category(pdf, category, index)
        end
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

      def render_category(pdf, category, index)
        category_name = category["name"]
        subcategories = category["subcategories"] || []
        resource_count = subcategories.sum { |s| (s["resource_ids"] || []).size }

        pdf.text "#{index + 1}. #{category_name}", size: 14, style: :bold
        pdf.move_down 4
        pdf.text "#{subcategories.size} #{I18n.t('custom.ai_stats.topic_clustering.subcategories')}, #{resource_count} #{I18n.t('custom.ai_stats.topic_clustering.resources')}", size: 10, color: "666666"
        pdf.move_down 8

        subcategories.each do |subcategory|
          render_subcategory(pdf, subcategory)
        end

        pdf.move_down 10
      end

      def render_subcategory(pdf, subcategory)
        subcategory_name = subcategory["name"]
        resource_ids = subcategory["resource_ids"] || []

        pdf.text "• #{subcategory_name} (#{resource_ids.size})", size: 10, indent_paragraphs: 15
        pdf.move_down 3
      end
  end
end
