class CreateSimilarContributionReferences < ActiveRecord::Migration[6.1]
  # A match found in another projekt cannot become a membership: memberships are
  # unique per contribution and RecordGroup merges every group a match already
  # belongs to, which would pull the earlier projekt's set into the current one.
  # A reference points at the foreign contribution from this projekt's group and
  # leaves that set untouched.
  def change
    create_table :similar_contribution_references do |t|
      t.integer :similar_contribution_group_id
      t.references :contribution, null: false, polymorphic: true, index: false
      t.integer :relevance
      t.string :reason

      t.timestamps
    end

    add_index :similar_contribution_references,
              [:similar_contribution_group_id, :contribution_type, :contribution_id],
              unique: true,
              name: "index_similar_contribution_references_on_group_and_contribution"
    add_index :similar_contribution_references,
              [:contribution_type, :contribution_id],
              name: "index_similar_contribution_references_on_contribution"
  end
end
