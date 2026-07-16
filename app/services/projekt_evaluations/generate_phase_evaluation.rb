class ProjektEvaluations::GeneratePhaseEvaluation < ApplicationService
  def initialize(projekt_phase_evaluation)
    @row = projekt_phase_evaluation
    @projekt_phase = projekt_phase_evaluation.projekt_phase
  end

  def self.regenerate_regular_stats(projekt_phase_evaluation)
    new(projekt_phase_evaluation).regenerate_regular_stats
  end

  def self.regenerate_ai_stats(projekt_phase_evaluation)
    new(projekt_phase_evaluation).regenerate_ai_stats
  end

  def call
    run do |base|
      next {} if base.blank?

      build_regular_data(base).merge(build_ai_data(base))
    end
  end

  def regenerate_regular_stats
    run do |base|
      next existing_data if base.blank?

      existing_data.merge(build_regular_data(base))
    end
  end

  def regenerate_ai_stats
    run do |base|
      next existing_data if base.blank?

      existing_data.merge(build_ai_data(base))
    end
  end

  private

  def run
    if !supported_phase_type?
      @row.destroy
      return nil
    end

    @row.update!(status: :processing)

    phase_data = yield(aggregate_phase_stats)

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

  def build_regular_data(base)
    refresh_precomputed_phase_stats

    base.merge(
      full_stats: ProjektPhaseStats::FullStatsCollector.call(@projekt_phase),
      regular_generated_at: Time.current.iso8601
    )
  end

  def refresh_precomputed_phase_stats
    service_class = ProjektPhase::StatsRefreshService::STATS_SERVICES[@projekt_phase.class]
    return if service_class.blank?

    service_class.new(@projekt_phase).call
    @projekt_phase.reload
  rescue StandardError => e
    Rails.logger.warn(
      "[Evaluation] precomputed stats refresh failed for phase ##{@projekt_phase.id}: #{e.message}"
    )
  end

  def build_ai_data(base)
    refresh_ai_stats

    ai_data = collect_ai_data

    {
      ai_stats: ai_data[:ai_stats],
      ai_stats_refreshed_at: ai_data[:ai_stats_refreshed_at],
      evaluation_summary: generate_phase_evaluation_summary(base),
      short_summary: generate_phase_short_summary(base),
      key_findings: generate_phase_key_findings(base),
      ai_generated_at: Time.current.iso8601
    }
  end

  def existing_data
    (@row.data || {}).deep_symbolize_keys
  end

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
