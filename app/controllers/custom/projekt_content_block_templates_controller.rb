class ProjektContentBlockTemplatesController < ApplicationController
  skip_authorization_check

  def index
    dt_templates_by_category = fetch_dt_templates

    render(
      Projekts::ContentBlockTemplatesSelectorContentComponent.new(
        dt_templates_by_category: dt_templates_by_category
      ),
      layout: false
    )
  end

  private

  def fetch_dt_templates
    cache_key = "dt_api/content_block_templates/all"

    parsed_response = DtApi::Caching.get_with_cache(
      cache_key,
      error_callback: -> { raise "DT API error: Failed to fetch content block templates and no cached version available" }
    ) do
      DtApi::Client.new.content_block_templates.all
    end

    parsed_response.dig("content_block_templates_by_category") || []
  rescue StandardError => e
    Rails.logger.error("Failed to fetch DT content block templates: #{e.message}")
    []
  end
end
