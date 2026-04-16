class AiAnalytics::ClusteringCore
  class << self
    def target_language
      Rails.env.development? ? "English" : "German"
    end

    def resource_type_name(resources)
      return "items" if resources.empty?

      if resources.first.is_a?(Budget::Investment)
        "investments"
      elsif resources.first.is_a?(Comment)
        "comments"
      else
        "proposals"
      end
    end

    def get_resources(projekt_phase)
      case projekt_phase
      when ProjektPhase::ProposalPhase
        projekt_phase.proposals.base_selection.to_a
      when ProjektPhase::BudgetPhase
        return [] unless projekt_phase.budget

        projekt_phase.budget.investments.to_a
      when ProjektPhase::CommentPhase
        projekt_phase.comments.to_a
      else
        []
      end
    end

    def prepare_resources_data(resources)
      resources.map do |resource|
        if resource.is_a?(Comment)
          { id: resource.id, content: resource.body&.truncate(400) }
        else
          { id: resource.id, title: resource.title, description: resource.description&.truncate(300) }
        end
      end.join("\n\n")
    end

    def output_schema
      {
        type: "object",
        properties: {
          topics: {
            type: "array",
            items: {
              type: "object",
              properties: {
                name: { type: "string" },
                subtopics: {
                  type: "array",
                  items: {
                    type: "object",
                    properties: {
                      name: { type: "string" },
                      resource_ids: {
                        type: "array",
                        items: { type: "integer" }
                      }
                    },
                    required: ["name", "resource_ids"],
                    additionalProperties: false
                  }
                }
              },
              required: ["name", "subtopics"],
              additionalProperties: false
            }
          }
        },
        required: ["topics"],
        additionalProperties: false
      }
    end
  end
end
