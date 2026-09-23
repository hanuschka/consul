class Ai::Tools::FetchContentBlockTemplates < RubyLLM::Tool
  MAX_CALLS = 3

  description "Fetches the full HTML of content block templates. Request everything " \
              "you might use in ONE call: pass category ids to get every template of " \
              "those categories, and template ids for individual templates. Pass an " \
              "empty array for the selector you do not need."

  params do
    array :category_ids,
          of: :string,
          description: "Category ids whose templates should be returned in full"
    array :template_ids,
          of: :string,
          description: "Individual template ids to fetch full content for"
  end

  def initialize(templates_by_category:, max_calls: MAX_CALLS)
    @templates_by_id = build_templates_index(templates_by_category)
    @template_ids_by_category_id = build_category_index(templates_by_category)
    @max_calls = max_calls
    @call_count = 0
  end

  # Every tool response makes RubyLLM re-enter the completion, so each extra
  # round costs a full LLM request. The prompt asks for a single call; refusing
  # here is what keeps a model that ignores it from looping.
  def execute(category_ids: [], template_ids: [])
    @call_count += 1

    if @call_count > @max_calls
      return {
        error: "Template fetch limit reached. Answer with the templates you already have."
      }
    end

    templates = templates_for(category_ids, template_ids)

    if templates.empty?
      return { error: "No templates found for the provided ids" }
    end

    { templates: templates }
  end

  private

  def templates_for(category_ids, template_ids)
    requested_ids = category_ids.to_a.flat_map { |id| @template_ids_by_category_id[id.to_s].to_a }
    requested_ids += template_ids.to_a.map(&:to_s)

    requested_ids.uniq.filter_map { |id| @templates_by_id[id] }
  end

  def build_templates_index(templates_by_category)
    index = {}

    templates_by_category.each do |category_data|
      category_name = category_data.dig("category", "name_de") || category_data.dig("category", "name")

      (category_data["templates"] || []).each do |template|
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

  def build_category_index(templates_by_category)
    index = {}

    templates_by_category.each do |category_data|
      category_id = category_data.dig("category", "id").to_s
      next if category_id.blank?

      index[category_id] = (category_data["templates"] || []).map { |template| template["id"].to_s }
    end

    index
  end
end
