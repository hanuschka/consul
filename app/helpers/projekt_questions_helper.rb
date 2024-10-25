module ProjektQuestionsHelper
  def cannot_answer_projekt_question_callout_text(permission_problem_key, projekt_phase)
    return nil if permission_problem_key.blank?

    sanitize(t("custom.projekt_phases.permission_problem.#{projekt_phase.resources_name}.#{permission_problem_key}",
             sign_in: link_to_signin, sign_up: link_to_signup,
             guest_sign_in: link_to_guest_signin,
             enter_missing_user_data: link_to_enter_missing_user_data,
             verify: link_to_verify_account,
             city: Setting["org_name"],
             geozones: projekt_phase.geozone_restrictions_formatted,
             age_restriction: projekt_phase.age_restriction_formatted,
             restricted_streets: projekt_phase.street_restrictions_formatted,
             individual_group_values: projekt_phase.individual_group_value_restriction_formatted
            ))
  end
end
