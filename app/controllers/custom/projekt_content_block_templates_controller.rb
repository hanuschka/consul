class ProjektContentBlockTemplatesController < ApplicationController
  def index
    authorize! :index, :projekt_content_block_templates

    render(
      Projekts::ContentBlockTemplatesSelectorContentComponent.new(
        templates_by_category: templates_by_category,
        context: template_context
      ),
      layout: false
    )
  end

  def metadata
    authorize! :index, :projekt_content_block_templates

    categories = templates_by_category.map do |category_data|
      {
        id: category_data.dig("category", "id").to_s,
        name: category_data.dig("category", "name_de").presence || category_data.dig("category", "name").to_s,
        templates: category_templates(category_data)
      }
    end

    render json: { available: true, categories: categories }
  end

  private

    def template_context
      params[:section] == "newsletter_email" ? "newsletter" : "projekt"
    end

    def category_templates(category_data)
      (category_data["templates"] || []).map do |template|
        {
          id: template["id"].to_s,
          name: template["name"].to_s,
          description: template["description"].to_s
        }
      end
    end

    def templates_by_category
      @templates_by_category ||= ContentBlockTemplates::Catalogue.call(section: params[:section])
    end
end
