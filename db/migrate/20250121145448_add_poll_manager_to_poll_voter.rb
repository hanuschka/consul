class AddPollManagerToPollVoter < ActiveRecord::Migration[6.1]
  def change
    add_reference :poll_voters, :poll_manager, foreign_key: true
  end
end
