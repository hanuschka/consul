class CreateRecipientGroups < ActiveRecord::Migration[6.1]
  def change
    create_table :recipient_groups do |t|
      t.string :name
      t.string :origin_class
      t.string :origin_method

      t.timestamps
    end
  end
end
