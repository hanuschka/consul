class Officing::PollsController < Officing::BaseController
  before_action :verify_booth

  def index
    @polls = current_user.poll_officer? ? current_user.poll_officer.voting_days_assigned_polls : []
    @polls = @polls.select { |poll| poll.current?(Time.current) || poll.current?(1.day.ago) }
  end

  def final
    @polls = if current_user.poll_officer?
               current_user.poll_officer.final_days_assigned_polls.select do |poll|
                 poll.projekt_phase.present? && poll.projekt_phase.end_date.present? &&
                   (poll.projekt_phase.end_date > 2.weeks.ago && poll.expired? || poll.projekt_phase.end_date.today?)
               end
             else
               []
             end
  end
end
