class AiProposalFlow::EvaluationResultComponent < ApplicationComponent
  MAX_SCORE_PER_CRITERION = 25

  STAGE_HARD_FAILED = "hard_failed".freeze
  STAGE_COMPLETED = "completed".freeze
  STAGE_ERROR = "error".freeze

  def initialize(evaluation_result:)
    @evaluation_result = evaluation_result || {}
  end

  def stage
    @evaluation_result["stage"].presence || legacy_stage
  end

  def hard_failed?
    stage == STAGE_HARD_FAILED
  end

  def error?
    stage == STAGE_ERROR
  end

  def failed_criterion
    @evaluation_result["failed_criterion"] || {}
  end

  def total_score
    @evaluation_result.dig("soft", "total_score") || @evaluation_result["total_score"]
  end

  def overall_feedback
    @evaluation_result.dig("soft", "overall_feedback") || @evaluation_result["overall_feedback"]
  end

  def soft_criteria
    @evaluation_result.dig("soft", "criteria") || @evaluation_result["criteria"] || []
  end

  def bar_modifier(score)
    if score >= 20 then ""
    elsif score >= 15 then "-medium"
    else "-low"
    end
  end

  private

    attr_reader :evaluation_result

    def legacy_stage
      return STAGE_HARD_FAILED if @evaluation_result["overall_passed"] == false

      STAGE_COMPLETED
    end
end
