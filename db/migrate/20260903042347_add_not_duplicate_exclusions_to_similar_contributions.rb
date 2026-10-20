class AddNotDuplicateExclusionsToSimilarContributions < ActiveRecord::Migration[6.1]
  def change
    create_table :similar_contribution_exclusions do |t|
      t.references :contribution, null: false, polymorphic: true, index: false
      t.references :excluded_contribution, null: false, polymorphic: true, index: false
      t.references :excluded_by, foreign_key: { to_table: :users }, index: true

      t.timestamps
    end

    add_index :similar_contribution_exclusions,
              [:contribution_type, :contribution_id,
               :excluded_contribution_type, :excluded_contribution_id],
              unique: true,
              name: "index_similar_contribution_exclusions_on_pair"

    add_index :similar_contribution_exclusions,
              [:contribution_type, :contribution_id],
              name: "index_similar_contribution_exclusions_on_contribution"
  end
end
