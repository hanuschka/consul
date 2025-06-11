class AddCreditsToImages < ActiveRecord::Migration[6.1]
  def change
    add_column :images, :credits, :string
  end
end
