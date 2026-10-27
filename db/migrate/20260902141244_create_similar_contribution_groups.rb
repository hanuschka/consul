class CreateSimilarContributionGroups < ActiveRecord::Migration[6.1]
  def change
    create_table :similar_contribution_groups do |t|
      t.references :projekt, null: false, foreign_key: true, index: true

      t.timestamps
    end

    create_table :similar_contribution_memberships do |t|
      t.references :similar_contribution_group, null: false, foreign_key: true,
                   index: { name: "index_similar_contribution_memberships_on_group_id" }
      t.references :contribution, null: false, polymorphic: true, index: false
      t.integer :relevance
      t.string :reason

      t.timestamps
    end

    add_index :similar_contribution_memberships,
              [:contribution_type, :contribution_id],
              unique: true,
              name: "index_similar_contribution_memberships_on_contribution"
  end
end
