module ConditionallyVotable
  extend ActiveSupport::Concern

  def conditional_vote_for?(user)
    return false unless user.is_a?(User)
    return false if user.verified?
    return false if projekt_phase.blank?

    projekt_phase.user_status == "verified" &&
      projekt_phase.feature?("resource.conditional_voting")
  end

  def conditional_vote_confirmable_for?(user)
    projekt_phase.present? && projekt_phase.permission_problem(user).blank?
  end

  def conditional_vote_cast_by?(user)
    return false unless user.is_a?(User)

    votes_for.where(voter: user, conditional: true).exists?
  end
end
