module CsvServices
  class ClusteringExporter < CsvServices::BaseService
    require "csv"

    def initialize(projekt_phase:, clustering_data:, resource_class:)
      @projekt_phase = projekt_phase
      @clustering_data = clustering_data
      @resource_class = resource_class
    end

    def call
      CSV.generate(headers: true, col_sep: ";", force_quotes: true, encoding: "UTF-8") do |csv|
        csv << headers
        build_rows.each { |row| csv << row }
      end
    end

    private

      def headers
        [
          I18n.t("custom.ai_stats.clustering_export.category"),
          I18n.t("custom.ai_stats.clustering_export.subcategory"),
          I18n.t("custom.ai_stats.clustering_export.resource_id"),
          I18n.t("custom.ai_stats.clustering_export.resource_title"),
          I18n.t("custom.ai_stats.clustering_export.resource_url")
        ]
      end

      def build_rows
        rows = []
        data = parse_clustering_data
        categories = data["categories"] || []

        categories.each do |category|
          category_name = category["name"]
          subcategories = category["subtopics"] || category["subcategories"] || []

          subcategories.each do |subcategory|
            subcategory_name = subcategory["name"]
            resource_ids = subcategory["resource_ids"] || subcategory["proposal_ids"] || []

            resources = fetch_resources(resource_ids)
            resources.each do |resource|
              rows << [
                sanitize_for_csv(category_name),
                sanitize_for_csv(subcategory_name),
                resource.id,
                sanitize_for_csv(resource_title(resource)),
                resource_url(resource)
              ]
            end
          end
        end

        rows
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

      def fetch_resources(ids)
        return [] if ids.blank?

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
        ""
      end
  end
end
