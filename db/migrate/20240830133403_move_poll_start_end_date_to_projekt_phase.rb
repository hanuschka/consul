class MovePollStartEndDateToProjektPhase < ActiveRecord::Migration[6.1]
  def up
    ProjektPhase::VotingPhase.find_each do |vp|
      next if vp.start_date.present? || vp.end_date.present?

      last_poll = vp.polls&.last
      next unless last_poll

      vp.update_columns(start_date: last_poll.starts_at, end_date: last_poll.ends_at)
    end
  end

  def down
  end
end
