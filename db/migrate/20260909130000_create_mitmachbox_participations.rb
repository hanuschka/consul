class CreateMitmachboxParticipations < ActiveRecord::Migration[6.1]
  def change
    create_table :mitmachbox_participations do |t|
      t.references :projekt_phase, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.bigint :survey_version_id, null: false

      t.timestamps
    end

    add_index :mitmachbox_participations,
      [:projekt_phase_id, :user_id, :survey_version_id],
      unique: true, name: "index_mitmachbox_participations_on_phase_user_version"
  end
end
