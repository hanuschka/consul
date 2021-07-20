require_dependency Rails.root.join("app", "helpers", "users_helper").to_s

module UsersHelper
  def proposal_limit_exceeded?(user)
    user.proposals.where(retired_at: nil).count >= Setting['extended_option.proposals.max_active_proposals_per_user'].to_i
  end

  def ck_editor_class(current_user)
   if extended_feature?("general.extended_editor_for_admins") && current_user.administrator?
     'extended'
   elsif extended_feature?("general.extended_editor_for_users") && !current_user.administrator?
     'extended'
   else
     'regular'
   end
  end

  def skip_user_verification?
    Setting["feature.user.skip_verification"].present?
  end

  def user_document_types
    [[t("custom.sign_up.user_details.card_name"), 'card'],
     [t("custom.sign_up.user_details.pass_name"), 'pass']]
  end
end
