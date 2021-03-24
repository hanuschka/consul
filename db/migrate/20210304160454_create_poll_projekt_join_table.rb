class CreatePollProjektJoinTable < ActiveRecord::Migration[5.1]
  def change
    create_join_table :polls, :projekts do |t|
      # t.index [:poll_id, :projekt_id]
      t.index [:projekt_id, :poll_id], unique: true
    end
  end
end
