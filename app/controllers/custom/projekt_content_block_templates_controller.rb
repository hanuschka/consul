class ProjektContentBlockTemplatesController < ApplicationController
  def index
    authorize! :index, :projekt_content_block_templates

    dt_templates_by_category = fetch_dt_templates

    if dt_templates_by_category.nil?
      head :service_unavailable
      return
    end

    render(
      Projekts::ContentBlockTemplatesSelectorContentComponent.new(
        dt_templates_by_category:
      ),
      layout: false
    )
  end

  private

    def fetch_dt_templates
      cache_key = "dt_api/content_block_templates/all"

      parsed_response = DtApi::Caching.get_with_cache(cache_key) do
        DtApi::Client.new.content_block_templates.all
      end

      parsed_response.dig("content_block_templates_by_category") || []
    rescue StandardError => e
      Rails.logger.error("Failed to fetch DT content block templates: #{e.message}")
      nil
    end
end
