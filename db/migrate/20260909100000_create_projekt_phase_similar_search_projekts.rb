class CreateProjektPhaseSimilarSearchProjekts < ActiveRecord::Migration[6.1]
  def change
    create_table :projekt_phase_similar_search_projekts do |t|
      t.integer :projekt_phase_id
      t.integer :projekt_id

      t.timestamps
    end

    add_index :projekt_phase_similar_search_projekts,
              [:projekt_phase_id, :projekt_id],
              unique: true,
              name: "index_projekt_phase_similar_search_projekts_on_pair"
    add_index :projekt_phase_similar_search_projekts, :projekt_id,
              name: "index_projekt_phase_similar_search_projekts_on_projekt_id"
  end
end
