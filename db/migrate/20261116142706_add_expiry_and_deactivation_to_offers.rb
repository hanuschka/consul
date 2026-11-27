class AddExpiryAndDeactivationToOffers < ActiveRecord::Migration[6.1]
  def change
    add_column :offers, :expires_on, :date
    add_column :offers, :deactivated_at, :datetime
  end
end
