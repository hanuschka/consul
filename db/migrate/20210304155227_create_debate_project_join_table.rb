class CreateDebateProjectJoinTable < ActiveRecord::Migration[5.1]
  def change
    create_join_table :debates, :projekts do |t|
      # t.index [:debate_id, :projekt_id]
      t.index [:projekt_id, :debate_id], unique: true
    end
  end
end
