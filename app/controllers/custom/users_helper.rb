require_dependency Rails.root.join("app", "helpers", "users_helper").to_s

module UsersHelper
  def proposal_limit_exceeded?(user)
    user.proposals.count >= Setting['max_active_proposals_per_user'].to_i
  end
end
