class Evaluations::GenerateEvaluation < ApplicationService
  def initialize(projekt, selected_question_ids: [])
    @projekt = projekt
    @selected_question_ids = selected_question_ids
  end

  def call
    evaluation = find_or_create_evaluation
    evaluation.update!(status: :processing)

    stats = Evaluations::AggregateStatistics.call(@projekt)

    ai_data = collect_ai_data
    ai_summary = generate_ai_summary(stats)
    selected_questions = collect_selected_questions

    evaluation.update!(
      status: :completed,
      generated_at: Time.current,
      data: {
        totals: stats[:totals],
        phases: merge_phase_data(stats[:phases], ai_data),
        ai_project_summary: ai_summary,
        selected_questions: selected_questions
      },
      selected_question_ids: @selected_question_ids
    )

    evaluation
  rescue StandardError => e
    evaluation&.update(status: :failed)
    Rails.logger.error("[Evaluation] Generation failed for Projekt ##{@projekt.id}: #{e.message}")

    raise
  end

  private

  def find_or_create_evaluation
    existing = @projekt.projekt_evaluation

    if existing.present?
      existing.update!(status: :pending, data: {})
      return existing
    end

    @projekt.create_projekt_evaluation!(status: :pending)
  end

  def collect_ai_data
    @projekt.projekt_phases.active.each_with_object({}) do |phase, hash|
      hash[phase.id] = {
        ai_stats: phase.ai_stats,
        ai_stats_refreshed_at: phase.ai_stats_refreshed_at&.iso8601
      }
    end
  end

  def generate_ai_summary(stats)
    Evaluations::GenerateAiProjectSummary.call(@projekt, stats)
  rescue StandardError => e
    Rails.logger.warn("[Evaluation] AI summary generation failed: #{e.message}")
    nil
  end

  def collect_selected_questions
    return [] if @selected_question_ids.blank?

    ProjektPhaseStatQuestion
      .where(id: @selected_question_ids)
      .completed
      .map do |sq|
        {
          id: sq.id,
          phase_id: sq.projekt_phase_id,
          question: sq.question,
          answer: sq.answer
        }
      end
  end

  def merge_phase_data(phases_stats, ai_data)
    phases_stats.map do |phase|
      phase_ai = ai_data[phase[:phase_id]] || {}

      phase.merge(
        stats: enrich_phase_stats(phase),
        ai_stats: phase_ai[:ai_stats],
        ai_stats_refreshed_at: phase_ai[:ai_stats_refreshed_at],
        evaluation_summary: generate_phase_evaluation_summary(phase),
        key_findings: generate_phase_key_findings(phase)
      )
    end
  end

  def enrich_phase_stats(phase)
    stats = phase[:stats] || {}
    return stats if phase[:phase_type] != "ProjektPhase::VotingPhase"

    stats.merge(
      polls: (stats[:polls] || []).map { |poll| enrich_poll_with_groupings(poll) }
    )
  end

  def enrich_poll_with_groupings(poll)
    questions = poll[:questions] || []
    return poll if questions.empty?

    groupings = Evaluations::GroupPollQuestions.call(questions)
    poll.merge(groupings: groupings)
  end

  def generate_phase_evaluation_summary(phase)
    case phase[:phase_type]
    when "ProjektPhase::ProposalPhase"
      Evaluations::GenerateProposalPhaseSummary.call(phase[:stats])
    when "ProjektPhase::VotingPhase"
      Evaluations::GenerateVotingPhaseSummary.call(phase[:stats])
    end
  end

  def generate_phase_key_findings(phase)
    Evaluations::GeneratePhaseKeyFindings.call(phase)
  end
end
