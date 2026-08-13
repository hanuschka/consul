class ProposalAiDraft::EvaluateTwoTierService < ApplicationService
  RESULT_VERSION = 2

  STAGE_HARD_FAILED = "hard_failed".freeze
  STAGE_COMPLETED = "completed".freeze
  STAGE_ERROR = "error".freeze

  def initialize(resource:)
    @resource = resource
  end

  def call
    result = orchestrate
    persist(result)
    result
  rescue StandardError => e
    Rails.logger.error("[ProposalAiDraft] EvaluateTwoTierService failed: #{e.class} - #{e.message}")
    error_result = build_error_result(e)
    persist(error_result)
    error_result
  end

  private

    def orchestrate
      hard_result = ProposalAiDraft::EvaluateHardCriteriaService.call(resource: @resource)

      if hard_failed?(hard_result)
        return hard_fail_result(hard_result)
      end

      soft_result = ProposalAiDraft::EvaluateSoftCriteriaService.call(resource: @resource)
      completed_result(hard_result, soft_result)
    end

    def hard_failed?(hard_result)
      hard_result["all_passed"] == false
    end

    def first_failing_criterion(hard_result)
      failing_ids = hard_result["criteria"].reject { |c| c["passed"] }.map { |c| c["id"] }
      return nil if failing_ids.empty?

      @resource
        .projekt_phase
        .user_resource_criteria
        .hard_kind
        .where(id: failing_ids)
        .first
    end

    def hard_fail_result(hard_result)
      first_failing_criterion_record = first_failing_criterion(hard_result)
      failing_feedback = hard_result["criteria"].find { |c| c["id"] == first_failing_criterion_record&.id }

      {
        "version" => RESULT_VERSION,
        "stage" => STAGE_HARD_FAILED,
        "failed_criterion" => {
          "id" => first_failing_criterion_record&.id,
          "name" => first_failing_criterion_record&.name,
          "description" => first_failing_criterion_record&.description,
          "feedback" => failing_feedback&.dig("feedback").to_s,
          "citizen_feedback" => failing_feedback&.dig("citizen_feedback").to_s
        },
        "hard" => hard_result,
        "soft" => nil
      }
    end

    def completed_result(hard_result, soft_result)
      {
        "version" => RESULT_VERSION,
        "stage" => STAGE_COMPLETED,
        "failed_criterion" => nil,
        "hard" => hard_result,
        "soft" => soft_result,
        "total_score" => soft_result["total_score"],
        "overall_feedback" => soft_result["overall_feedback"]
      }
    end

    def build_error_result(error)
      {
        "version" => RESULT_VERSION,
        "stage" => STAGE_ERROR,
        "error_class" => error.class.name,
        "error_message" => error.message
      }
    end

    def persist(result)
      return if @resource.blank?

      @resource.update_columns(
        ai_evaluation_result: result,
        updated_at: Time.current
      )
    end
end
