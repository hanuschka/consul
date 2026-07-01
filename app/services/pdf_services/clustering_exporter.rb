module PdfServices
  class ClusteringExporter
    def initialize(projekt_phase:, clustering_data:, clustering_type:, resource_class: nil)
      @projekt_phase = projekt_phase
      @clustering_data = clustering_data
      @clustering_type = clustering_type
      @resource_class = resource_class
    end

    def call
      Prawn::Fonts::AFM.hide_m17n_warning = true

      Prawn::Document.new(page_size: "A4", margin: [40, 50, 40, 50]) do |pdf|
        render_header(pdf)
        render_metadata(pdf)
        add_separator_line(pdf)
        render_summary(pdf)
        pdf.move_down 20
        render_categories(pdf)
        add_footer(pdf)
      end
    end

    private

      def render_header(pdf)
        title_key = @clustering_type == :topic ? "pdf_title_topic" : "pdf_title_semantic"
        base_title = I18n.t("custom.ai_stats.clustering_export.#{title_key}")
        projekt_name = @projekt_phase.projekt.title

        pdf.text "#{base_title} - #{projekt_name}", size: 24, style: :bold
        pdf.move_down 15
      end

      def render_metadata(pdf)
        projekt = @projekt_phase.projekt

        pdf.fill_color "555555"
        pdf.formatted_text [
          { text: "#{I18n.t('custom.ai_stats.clustering_export.pdf_projekt')}: ", styles: [:bold], size: 11, color: "333333" },
          { text: projekt.title, size: 11, color: "333333" }
        ]
        pdf.move_down 5

        pdf.formatted_text [
          { text: "#{I18n.t('custom.ai_stats.clustering_export.pdf_phase')}: ", styles: [:bold], size: 11, color: "333333" },
          { text: @projekt_phase.title, size: 11, color: "333333" }
        ]
        pdf.move_down 5

        pdf.formatted_text [
          { text: "#{I18n.t('custom.ai_stats.clustering_export.pdf_exported')}: ", styles: [:bold], size: 11, color: "333333" },
          { text: Time.current.strftime("%d.%m.%Y %H:%M"), size: 11, color: "333333" }
        ]
        pdf.fill_color "000000"
        pdf.move_down 15
      end

      def add_separator_line(pdf)
        pdf.stroke_color "cccccc"
        pdf.stroke_horizontal_rule
        pdf.stroke_color "000000"
        pdf.move_down 15
      end

      def render_summary(pdf)
        data = parse_clustering_data
        categories = data["categories"] || []
        total_resources = categories.sum { |c|
          (c["subtopics"] || c["subcategories"] || []).sum { |s| get_resource_ids(s).size }
        }

        pdf.fill_color "f5f5f5"
        pdf.fill_rectangle [0, pdf.cursor], pdf.bounds.width, 45
        pdf.fill_color "000000"

        pdf.move_down 12
        pdf.indent(15) do
          pdf.formatted_text [
            { text: "#{categories.size} ", size: 16, styles: [:bold], color: "1a5490" },
            { text: "#{I18n.t('custom.ai_stats.topic_clustering.category_groups')}    ", size: 11, color: "4a5568" },
            { text: "#{total_resources} ", size: 16, styles: [:bold], color: "1a5490" },
            { text: I18n.t('custom.ai_stats.topic_clustering.resources'), size: 11, color: "4a5568" }
          ]
        end
        pdf.move_down 12
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

      def render_category(pdf, category, index)
        pdf.start_new_page if pdf.cursor < 100 && index > 0

        category_name = category["name"]
        subcategories = category["subtopics"] || category["subcategories"] || []
        resource_count = subcategories.sum { |s| get_resource_ids(s).size }

        pdf.fill_color "e8f4f8"
        pdf.fill_rectangle [0, pdf.cursor], pdf.bounds.width, 45
        pdf.fill_color "000000"

        pdf.move_down 8
        pdf.indent(10) do
          pdf.formatted_text [
            { text: "#{index + 1}. ", size: 16, styles: [:bold], color: "1a5490" },
            { text: category_name, size: 16, styles: [:bold], color: "1a5490" }
          ]
          pdf.move_down 3
          pdf.formatted_text [
            { text: "#{subcategories.size} #{I18n.t('custom.ai_stats.topic_clustering.subcategories')} • #{resource_count} #{I18n.t('custom.ai_stats.topic_clustering.resources')}", size: 10, color: "4a5568" }
          ]
        end
        pdf.move_down 10

        subcategories.each do |subcategory|
          render_subcategory(pdf, subcategory)
        end

        pdf.move_down 15
      end

      def render_subcategory(pdf, subcategory)
        subcategory_name = subcategory["name"]
        resource_ids = get_resource_ids(subcategory)

        pdf.indent(10) do
          pdf.formatted_text [
            { text: subcategory_name, size: 12, styles: [:bold], color: "333333" },
            { text: " (#{resource_ids.size})", size: 10, color: "999999" }
          ]
        end
        pdf.move_down 8

        if @resource_class.present? && resource_ids.any?
          resources = fetch_resources(resource_ids)
          resources.each_with_index do |resource, idx|
            render_resource(pdf, resource, idx)
          end
        end

        pdf.move_down 8
      end

      def get_resource_ids(subcategory)
        subcategory["resource_ids"] || subcategory["proposal_ids"] || []
      end

      def fetch_resources(ids)
        return [] if ids.blank? || @resource_class.nil?

        @resource_class.where(id: ids)
      end

      def render_resource(pdf, resource, index)
        pdf.start_new_page if pdf.cursor < 50

        title = resource_title(resource)
        url = resource_url(resource)

        pdf.indent(25) do
          pdf.fill_color "f9f9f9"
          bounding_box_height = 35
          bounding_box_height += 12 if url.present?

          pdf.fill_rectangle [0, pdf.cursor], pdf.bounds.width - 25, bounding_box_height
          pdf.fill_color "000000"

          pdf.move_down 8
          pdf.indent(10) do
            pdf.text title, size: 12, style: :bold, color: "333333"
            pdf.move_down 3

            if url.present?
              pdf.formatted_text [
                { text: url, size: 10, link: url, color: "2563eb" }
              ]
              pdf.move_down 3
            end
          end
          pdf.move_down 8
        end
        pdf.move_down 4
      end

      def add_footer(pdf)
        pdf.number_pages "Seite <page> von <total>",
          at: [pdf.bounds.right - 100, 0],
          align: :right,
          size: 9,
          color: "999999"
      end

      def resource_url(resource)
        Rails.application.routes.url_helpers.polymorphic_url(
          resource,
          **UrlOptions.default
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
  end
end
