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
    response = DtApi::Client.new.content_block_templates.all

    if response.success?
      response.parsed_response.dig("content_block_templates_by_category") || []
    else
      []
    end
  rescue StandardError => e
    Rails.logger.error("Failed to fetch DT content block templates: #{e.message}")
    []
  end
end
