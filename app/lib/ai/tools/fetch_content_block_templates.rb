class Ai::Tools::FetchContentBlockTemplates < RubyLLM::Tool
  description "Fetches full HTML content of content block templates by their IDs. " \
              "Use this tool when you want to see the actual HTML structure of specific templates " \
              "to use as reference for generating content blocks."

  params do
    array :template_ids, of: :string, description: "List of template IDs to fetch full content for"
  end

  def initialize(templates_by_category:)
    @templates_index = build_templates_index(templates_by_category)
  end

  def execute(template_ids:)
    results = template_ids.filter_map { |id| @templates_index[id.to_s] }

    if results.empty?
      return { error: "No templates found for the provided IDs" }
    end

    { templates: results }
  end

  private

  def build_templates_index(templates_by_category)
    index = {}

    templates_by_category.each do |category_data|
      category_name = category_data.dig("category", "name_de") || category_data.dig("category", "name")
      templates = category_data["templates"] || []

      templates.each do |template|
        id = template["id"].to_s
        index[id] = {
          id: id,
          name: template["name"],
          category: category_name,
          content: template["content"]
        }
      end
    end

    index
  end
end
