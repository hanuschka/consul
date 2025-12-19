class Shared::CommentsFormComponent < ApplicationComponent
  attr_reader :record
  delegate :user_signed_in?, :link_to_signin, :link_to_signup, :link_to_guest_signin, :link_to_enter_missing_user_data,
           :link_to_verify_account, :current_user, :can?, to: :helpers

  def initialize(record)
    @record = record
  end

  private

    def render?
      return true if user_signed_in? && (current_user.administrator? || current_user.has_pm_permission_to?(:manage, @projekt))
      return true unless record.class.name.in? %w[Proposal Budget::Investment Poll]

      helpers.projekt_phase_feature?(record.projekt_phase, "resource.show_comments")
    end

    def projekt_phase
      return nil if record.is_a?(Projekt)
      return record if record.is_a?(ProjektPhase)
      return record.projekt_phase if record.respond_to?(:projekt_phase)

      nil
    end

    def permission_problem_key
      return nil if projekt_phase.blank?

      @permission_problem_key ||= projekt_phase.permission_problem(current_user) || record_permission_problem_key
    end

    def record_permission_problem_key
      return if current_user&.administrator? || current_user&.projekt_manager?

      :investment_unfeasible if record.is_a?(Budget::Investment) && record.unfeasible? && record.valuation_finished?
    end

    def cannot_vote_text
      return nil if permission_problem_key.blank?

      sanitize(t(path_to_key,
               sign_in: link_to_signin, sign_up: link_to_signup,
               guest_sign_in: link_to_guest_signin,
               enter_missing_user_data: link_to_enter_missing_user_data,
               verify: link_to_verify_account,
               city: Setting["org_name"],
               geozones: projekt_phase.geozone_restrictions_formatted,
               registered_address_groupings: projekt_phase.registered_address_grouping_restriction_formatted,
               age_restriction: projekt_phase.age_restriction_formatted,
               restricted_streets: projekt_phase.street_restrictions_formatted,
               individual_group_values: projekt_phase.individual_group_value_restriction_formatted
      ))
    end

    def path_to_key
      if record.respond_to?(:projekt_phase) &&
        I18n.exists?("custom.projekt_phases.permission_problem.commenting.#{record.projekt_phase.name}.#{permission_problem_key}")
        "custom.projekt_phases.permission_problem.commenting.#{record.projekt_phase.name}.#{permission_problem_key}"
      else
        "custom.projekt_phases.permission_problem.commenting.shared.#{permission_problem_key}"
      end
    end

    def exception_for_investment?
      return true if record.is_a?(Budget::Investment) && record.unfeasible? && record.valuation_finished?
      return true if record.is_a?(Budget::Investment) && !record.budget.current_phase.kind.in?(%w[informing accepting reviewing])

      false
    end
end
