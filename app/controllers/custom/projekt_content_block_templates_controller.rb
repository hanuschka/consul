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
      parsed_response = DtApi::Client.new(use_cache: true)
        .content_block_templates
        .all(section: params[:section])
        .parsed_response

      parsed_response.dig("content_block_templates_by_category") || []
    rescue StandardError => e
      Rails.logger.error("Failed to fetch DT content block templates: #{e.message}")
      nil
    end
end
