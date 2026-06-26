class ProjektContentBlockTemplatesController < ApplicationController
  def index
    authorize! :index, :projekt_content_block_templates

    dt_templates_by_category = fetch_dt_templates

    render(
      Projekts::ContentBlockTemplatesSelectorContentComponent.new(
        dt_templates_by_category: dt_templates_by_category.presence || [],
        context: template_context,
        fallback: dt_templates_by_category.blank?
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

    def template_context
      params[:section] == "newsletter_email" ? "newsletter" : "projekt"
    end

    def local_categories_fallback
      if template_context == "newsletter"
        return [
          {
            id: "email_defaults",
            name: I18n.t("custom.newsletters.content_block_templates_selector.tabs.email_defaults"),
            templates: name_only(Newsletters::ContentBlockTemplatesSelectorComponent::EMAIL_TEMPLATE_NAMES)
          }
        ]
      end

      selector = Projekts::ContentBlockTemplatesSelectorComponent.new
      local_categories = selector.local_template_categories.map do |category|
        { id: category[:id], name: category[:name], templates: name_only(category[:template_names]) }
      end

      local_categories + [
        {
          id: "messages",
          name: I18n.t("custom.projekt.content_block_templates_selector.tabs.messages"),
          templates: name_only(selector.messages_content_block_templates)
        }
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
