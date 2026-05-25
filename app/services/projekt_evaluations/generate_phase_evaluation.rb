class ProjektEvaluations::GeneratePhaseEvaluation < ApplicationService
  def initialize(projekt_phase_evaluation)
    @row = projekt_phase_evaluation
    @projekt_phase = projekt_phase_evaluation.projekt_phase
  end

  def call
    if !supported_phase_type?
      @row.destroy
      return nil
    end

    @row.update!(status: :processing)

    refresh_ai_stats

    phase_data = build_phase_data

    @row.update!(
      status: :completed,
      generated_at: Time.current,
      data: phase_data.deep_stringify_keys
    )

    @row
  rescue StandardError => e
    @row.update(status: :failed)
    Rails.logger.error(
      "[Evaluation] Phase generation failed for row ##{@row.id} (phase ##{@projekt_phase.id}): #{e.message}"
    )

    raise
  end

  def build_phase_data
    base = aggregate_phase_stats
    return {} if base.blank?

    ai_data = collect_ai_data
    full_stats = ProjektPhaseStats::FullStatsCollector.call(@projekt_phase)

    base.merge(
      stats: enrich_phase_stats(base),
      ai_stats: ai_data[:ai_stats],
      ai_stats_refreshed_at: ai_data[:ai_stats_refreshed_at],
      full_stats: full_stats,
      evaluation_summary: generate_phase_evaluation_summary(base),
      short_summary: generate_phase_short_summary(base),
      key_findings: generate_phase_key_findings(base)
    )
  end

  private

  def supported_phase_type?
    ProjektEvaluations::AggregateStatistics::PHASE_COLLECTORS.key?(@projekt_phase.type)
  end

  def refresh_ai_stats
    return if ProjektPhaseStats::FullStatsCollector::SUPPORTED_PHASES.none? { |k| @projekt_phase.is_a?(k) }

    AiAnalytics::ProjektPhaseStatsRefresh.perform_now(@projekt_phase.id)
    @projekt_phase.reload
  rescue StandardError => e
    Rails.logger.warn(
      "[Evaluation] ai_stats refresh failed for phase ##{@projekt_phase.id}: #{e.message}"
    )
  end

  def aggregate_phase_stats
    ProjektEvaluations::AggregateStatistics.new(@projekt_phase.projekt).call_for_phase(@projekt_phase)
  end

  def collect_ai_data
    {
      ai_stats: @projekt_phase.ai_stats,
      ai_stats_refreshed_at: @projekt_phase.ai_stats_refreshed_at&.iso8601
    }
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

    groupings = ProjektEvaluations::GroupPollQuestions.call(questions)
    poll.merge(groupings: groupings)
  end

  def generate_phase_evaluation_summary(phase)
    case phase[:phase_type]
    when "ProjektPhase::ProposalPhase"
      ProjektEvaluations::GenerateProposalPhaseSummary.call(phase[:stats])
    when "ProjektPhase::VotingPhase"
      ProjektEvaluations::GenerateVotingPhaseSummary.call(phase[:stats])
    end
  end

  def generate_phase_key_findings(phase)
    ProjektEvaluations::GeneratePhaseKeyFindings.call(phase)
  end

  def generate_phase_short_summary(phase)
    ProjektEvaluations::GeneratePhaseShortSummary.call(phase)
  rescue StandardError => e
    Rails.logger.warn("[Evaluation] Phase short summary generation failed: #{e.message}")
    nil
  end
end
