class AiProposalFlow::EvaluationResultComponent < ApplicationComponent
  def initialize(evaluation_result:)
    @evaluation_result = evaluation_result || {}
  end

  def total_score
    @evaluation_result["total_score"]
  end

  def overall_passed
    @evaluation_result["overall_passed"]
  end

  def overall_feedback
    @evaluation_result["overall_feedback"]
  end

  def criteria
    @evaluation_result["criteria"] || []
  end

  def bar_modifier(score)
    if score >= 20 then ""
    elsif score >= 15 then "-medium"
    else "-low"
    end
  end

  private

    attr_reader :evaluation_result
end
