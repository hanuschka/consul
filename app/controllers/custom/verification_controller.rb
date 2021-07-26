require_dependency Rails.root.join("app", "controllers", "verification_controller").to_s
class VerificationController < ApplicationController

  private

    def next_step_path(user = current_user)
      if user.organization?
        { path: account_path }
      elsif user.level_three_verified?
        { path: account_path, notice: t("verification.redirect_notices.already_verified") }
      elsif user.bam_letter_verification_code.present? && !user.citizen?
        { path: collect_user_verification_code_path }
      elsif !user.citizen?
        { path: collect_user_details_path }
      elsif user.citizen?
        { path: collect_user_details_path }
      else
        { path: account_path }
      end
    end
end
