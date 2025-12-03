class AiAnalytics::SemanticClustering < ApplicationService
  attr_reader :projekt_phase

  def initialize(projekt_phase)
    @projekt_phase = projekt_phase
  end

  def call
    proposals = get_proposals
    return { "topics" => [] } if proposals.empty?

    generate_clustering(proposals)
  end

  private

    def target_language
      Rails.env.development? ? "English" : "German"
    end

    def get_proposals
      case projekt_phase
      when ProjektPhase::ProposalPhase
        projekt_phase.proposals.base_selection.to_a
      when ProjektPhase::BudgetPhase
        return [] unless projekt_phase.budget

        projekt_phase.budget.investments.to_a
      else
        []
      end
    end

    def generate_clustering(proposals)
      proposals_text = proposals.map do |proposal|
        "Proposal ID: #{proposal.id}, Proposal text: #{proposal.title}. #{proposal.description&.truncate(300)}"
      end.join("\n\n")

      prompt = <<~TEXT
        You are an AI specialized in semantic analysis, topic extraction, and hierarchical clustering.

        Your task is to analyze a list of proposals and generate a meaningful topic structure.

        Your goals:

        Perform a semantic analysis of all proposals.

        Identify underlying themes, intentions, target groups, and conceptual similarities.
        Ignore superficial wording; focus on meaning.
        Based on your semantic understanding, create 5–7 high-level TOPICS that best represent the conceptual structure of the data.
        For each topic, create 2–4 SUBTOPICS that capture finer semantic distinctions.
        Assign each proposal to exactly one subtopic (whichever has the strongest semantic fit).
        Ensure topics and subtopics are: meaningful and human-friendly, non-overlapping , comprehensive (cover everything),
        semantically justified (not based on superficial keywords),
        Write all topic and subtopic names in #{target_language}.

        Proposals:
        #{proposals_text}
      TEXT

      response = Ai::RubyLlmFactory.chat_with_json_output(output_schema).ask(prompt)

      response.content
    rescue StandardError => e
      Rails.logger.error("SemanticClustering error: #{e.message}")
      { "topics" => [] }
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
                      proposal_ids: {
                        type: "array",
                        items: { type: "integer" }
                      }
                    },
                    required: ["name", "proposal_ids"],
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

