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

  def metadata
    authorize! :index, :projekt_content_block_templates

    dt_templates_by_category = fetch_dt_templates

    if dt_templates_by_category.present?
      categories = dt_templates_by_category.map do |category_data|
        templates = (category_data["templates"] || []).map do |t|
          {
            id: t["id"].to_s,
            name: t["name"].to_s,
            description: t["description"].to_s
          }
        end

        {
          id: category_data.dig("category", "id").to_s,
          name: category_data.dig("category", "name_de").presence || category_data.dig("category", "name").to_s,
          templates: templates
        }
      end

      render json: { available: true, categories: categories }
    else
      render json: { available: false, categories: local_categories_fallback }
    end
  end

  private

    def local_categories_fallback
      selector = Projekts::ContentBlockTemplatesSelectorComponent.new

      [
        { id: "basic_content", name: "Basisinhalte", templates: name_only(selector.basic_content_templates) },
        { id: "status_and_notes", name: "Status & Hinweise", templates: name_only(selector.status_and_notes_templates) },
        { id: "teasers_and_promotions", name: "Teaser und Werbeaktionen", templates: name_only(selector.teasers_and_promotions) },
        { id: "media_and_resources", name: "Medien & Ressourcen", templates: name_only(selector.media_and_resources_templates) },
        { id: "messages", name: "Nachrichten", templates: name_only(selector.messages_content_block_templates) }
      ]
    end

    def name_only(names)
      names.map { |n| { id: nil, name: n.to_s, description: "" } }
    end

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
