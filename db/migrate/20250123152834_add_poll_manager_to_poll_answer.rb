class AddPollManagerToPollAnswer < ActiveRecord::Migration[6.1]
  def change
    add_reference :poll_answers, :poll_manager, foreign_key: true
  end
end
