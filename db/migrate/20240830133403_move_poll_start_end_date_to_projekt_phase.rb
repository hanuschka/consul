class MovePollStartEndDateToProjektPhase < ActiveRecord::Migration[6.1]
  def up
    ProjektPhase::VotingPhase.find_each do |vp|
      next if vp.start_date.present? || vp.end_date.present?

      first_poll = vp.polls&.first
      next unless first_poll

      vp.update_columns(start_date: first_poll.starts_at, end_date: first_poll.ends_at)
    end
  end

  def down
  end
end
