class ProjektEvaluations::GenerateAiProjectSummary < ApplicationService
  DESCRIPTION_TRUNCATE = 500

  def initialize(projekt, stats)
    @projekt = projekt
    @stats = stats
  end

  def call
    get_ai_response(build_user_prompt)
  rescue StandardError => e
    Rails.logger.error("[Evaluation] GenerateAiProjectSummary failed: #{e.message}")
    nil
  end

  private

    def target_language
      Rails.env.development? ? "English" : "German"
    end

    def system_instructions
      <<~TEXT
        You are summarizing a citizen participation project for an internal
        evaluation report.

        Write 3 to 5 sentences of plain prose in #{target_language}, covering the goals of the
        project, how broadly citizens took part and the most important results.
        Output plain text only: no HTML, no markdown, no bullet points, no headings.
      TEXT
    end

    def get_ai_response(user_prompt)
      response = Ai::RubyLlmFactory
        .chat(feature: "projekt_evaluations.ai_project_summary")
        .with_instructions(Ai::EvaluationContext.prepend_to(system_instructions, @projekt))
        .ask(user_prompt)

      response.content.to_s.strip.presence
    end

    def build_user_prompt
      <<~TEXT
        Project name: #{@projekt.name}
        Description: #{@projekt.description.to_s.truncate(DESCRIPTION_TRUNCATE)}
        Duration: #{@projekt.total_duration_start} to #{@projekt.total_duration_end}

        Overall statistics:
        - #{totals[:total_participants]} participants
        - #{totals[:total_contributions]} contributions
        - #{totals[:total_supports]} supports
        - #{totals[:phases_count]} participation phases

        Phases:
        #{phases_summary}
      TEXT
    end

    def totals
      @stats[:totals] || {}
    end

    def phases_summary
      (@stats[:phases] || []).map do |phase|
        "- #{phase[:phase_title]} (#{phase[:phase_type].to_s.demodulize}): " \
          "#{format_phase_stats(phase[:stats] || {})}"
      end.join("\n")
    end

    def format_phase_stats(stats)
      parts = []
      parts << "#{stats[:proposals_count]} proposals" if stats[:proposals_count]
      parts << "#{stats[:investments_count]} investments" if stats[:investments_count]
      parts << "#{stats[:participants_count]} participants" if stats[:participants_count]
      parts << "#{stats[:comments_count]} comments" if stats[:comments_count]
      parts << "#{stats[:supports_count]} supports" if stats[:supports_count]

      parts.join(", ")
    end
end
