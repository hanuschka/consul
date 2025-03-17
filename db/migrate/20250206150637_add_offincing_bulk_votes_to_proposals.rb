class AddOffincingBulkVotesToProposals < ActiveRecord::Migration[6.1]
  def change
    add_column :proposals, :officing_bulk_votes, :integer, default: 0
  end
end
