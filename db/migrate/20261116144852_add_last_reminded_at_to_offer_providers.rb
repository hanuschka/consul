class AddLastRemindedAtToOfferProviders < ActiveRecord::Migration[6.1]
  def change
    add_column :offer_providers, :last_reminded_at, :datetime
  end
end
