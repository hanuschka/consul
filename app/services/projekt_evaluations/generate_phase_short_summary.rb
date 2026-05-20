class ProjektEvaluations::GeneratePhaseShortSummary < ApplicationService
  def initialize(phase)
    @phase = phase
  end

  def call
    return nil if phase_data_blank?

    response_text = get_ai_response(build_user_prompt)
    response_text.to_s.strip.presence
  rescue StandardError => e
    Rails.logger.error("[Evaluation] GeneratePhaseShortSummary failed: #{e.message}")
    nil
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
        .chat
        .with_instructions(system_instructions)
        .ask(user_prompt)

      response.content.to_s
    end

    def system_instructions
      <<~TEXT
        You are summarizing one phase of a citizen participation project for an executive overview.
        Write exactly 1 to 2 short sentences in #{target_language} that capture what happened in this phase
        based on the stats: highlight participation level and main quantitative outcome.
        No bullet points, no lists, no markdown, no headings. Output only the prose summary.
      TEXT
    end
end
