class AddReviewAndHiddenToOffers < ActiveRecord::Migration[6.1]
  def change
    add_column :offers, :review_status, :integer, default: 0, null: false
    add_column :offers, :hidden_at, :datetime
    add_index :offers, :review_status
  end
end
