module OfficersHelper
  def vote_collection_shift?
    return false unless current_user.poll_officer?

    current_user.poll_officer.officer_assignments.voting_days.where(date: Time.current.to_date).any?
  end

  def final_recount_shift?
    return false unless current_user.poll_officer?

    current_user.poll_officer.officer_assignments.final.where(date: Time.current.to_date).any?
  end

  def no_shifts?
    return false unless current_user.poll_officer?

    current_user.poll_officer.officer_assignments.where(date: Time.current.to_date).blank?
  end
end
