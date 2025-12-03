class AiAnalytics::TopicClustering < ApplicationService
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
        projekt_phase.proposals.to_a
      when ProjektPhase::BudgetPhase
        return [] unless projekt_phase.budget

        projekt_phase.budget.investments.to_a
      else
        []
      end
    end

    def generate_clustering(proposals)
      proposals_text = proposals.map do |proposal|
        "ID: #{proposal.id}, Title: #{proposal.title}, Description: #{proposal.description&.truncate(300)}"
      end.join("\n\n")

      prompt = <<~TEXT
        You are an AI specialized in semantic clustering and topic modeling.

        Your task is to create a clean and logical categorization system for a list of proposals.

        What you must do:

        1. Read the full list of proposals (see below).
        2. Identify patterns, themes and semantic clusters in the proposals.
        3. Generate 5–7 meaningful TOPICS (your choice — choose what fits the data best).
        4. For each topic, generate 2–4 SUBTOPICS that further structure the content.
        5. Assign every proposal to exactly one subtopic using its ID.

        Make sure topics and subtopics:
        - are non-overlapping,
        - are easy to understand for non-experts,
        - cover all proposals without forcing them unnaturally.

        Write all topic and subtopic names in #{target_language}.

        Proposals:
        #{proposals_text}
      TEXT

      response = Ai::RubyLlmFactory.chat_with_json_output(output_schema).ask(prompt)

      response.as_json
    rescue JStandardError => e
      Rails.logger.error("TopicClustering error: #{e.message}")
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
