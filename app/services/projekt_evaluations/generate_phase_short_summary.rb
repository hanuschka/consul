class ProjektEvaluations::GeneratePhaseShortSummary < ApplicationService
  def initialize(phase)
    @phase = phase
  end

  def call
    return [] if phase_data_blank?

    parse_response(get_ai_response(build_user_prompt))
  rescue StandardError => e
    Rails.logger.error("[Evaluation] GeneratePhaseShortSummary failed: #{e.message}")
    []
  end

  private

    attr_reader :phase

    def phase_type
      phase[:phase_type] || phase["phase_type"]
    end

    def phase_title
      phase[:phase_title] || phase["phase_title"]
    end

    def phase_stats
      phase[:stats] || phase["stats"] || {}
    end

    def stat(key)
      phase_stats[key] || phase_stats[key.to_s]
    end

    def phase_data_blank?
      case phase_type
      when "ProjektPhase::ProposalPhase"
        stat(:proposals_count).to_i.zero?
      when "ProjektPhase::VotingPhase"
        stat(:participants_count).to_i.zero? && stat(:questions_count).to_i.zero?
      when "ProjektPhase::BudgetPhase"
        stat(:investments_count).to_i.zero?
      when "ProjektPhase::CommentPhase"
        stat(:comments_count).to_i.zero?
      else
        true
      end
    end

    def target_language
      Rails.env.development? ? "English" : "German"
    end

    def build_user_prompt
      <<~TEXT
        Phase: "#{phase_title}" (type: #{phase_type.to_s.demodulize})
        Stats:
        #{format_stats}
      TEXT
    end

    def format_stats
      lines = []
      lines << "  - proposals: #{stat(:proposals_count)}" if stat(:proposals_count)
      lines << "  - investments: #{stat(:investments_count)}" if stat(:investments_count)
      lines << "  - participants: #{stat(:participants_count) || stat(:unique_participants)}" if stat(:participants_count) || stat(:unique_participants)
      lines << "  - supports: #{stat(:supports_count)}" if stat(:supports_count)
      lines << "  - comments: #{stat(:comments_count)}" if stat(:comments_count)
      lines << "  - polls: #{stat(:polls_count)}" if stat(:polls_count)
      lines << "  - questions: #{stat(:questions_count)}" if stat(:questions_count)
      lines << "  - open text contributions: #{stat(:open_text_count)}" if stat(:open_text_count)

      lines.join("\n")
    end

    def get_ai_response(user_prompt)
      response = Ai::RubyLlmFactory
        .chat(feature: "projekt_evaluations.phase_short_summary")
        .with_schema(output_schema)
        .with_instructions(system_instructions)
        .ask(user_prompt)

      response.content
    end

    def output_schema
      {
        type: "object",
        additionalProperties: false,
        properties: {
          sections: {
            type: "array",
            items: {
              type: "object",
              additionalProperties: false,
              properties: {
                heading: { type: "string", description: "2-5 word section subheading in the target language" },
                body: { type: "string", description: "2-3 sentences of plain prose in the target language" }
              },
              required: %w[heading body]
            }
          }
        },
        required: %w[sections]
      }
    end

    def system_instructions
      <<~TEXT
        You are summarizing one phase of a citizen participation project for an executive overview.
        Produce a thorough, descriptive summary in #{target_language}, organized into 3 to 4
        sections. Across all sections combined, write 7 to 10 sentences in total (about 2 to 3
        sentences per section).

        Each section has two parts:
        - heading: a short 2 to 5 word subheading in #{target_language} naming what the section
          covers (for example: participation, main outcomes, significance).
        - body: 2 to 3 sentences of plain prose in #{target_language}.

        Together the sections should cover: what this phase was about and its role within the
        participation process; the overall level and breadth of participation; each of the main
        quantitative outcomes present in the stats and what they indicate; the relationships
        between the metrics (for example how actively participants engaged relative to their
        number); and a closing observation about the phase's significance or contribution to the
        project.

        Each sentence must add new information; do not pad or repeat. Stay strictly grounded in
        the provided stats and do not invent numbers, names, or facts that are not given. Body
        text must be plain prose only: no bullet points, no lists, no markdown, no headings, and
        no HTML tags.
      TEXT
    end

    def parse_response(content)
      data = content.is_a?(String) ? JSON.parse(content) : content
      return [] unless data.is_a?(Hash)

      sections = data["sections"] || data[:sections]
      return [] unless sections.is_a?(Array)

      sections.filter_map { |section| build_section(section) }
    rescue JSON::ParserError => e
      Rails.logger.error("[Evaluation] Failed to parse phase short summary: #{e.message}")
      []
    end

    def build_section(section)
      return nil unless section.is_a?(Hash)

      body = (section["body"] || section[:body]).to_s.strip
      return nil if body.blank?

      heading = (section["heading"] || section[:heading]).to_s.strip

      { heading: heading, body: body }
    end
end
