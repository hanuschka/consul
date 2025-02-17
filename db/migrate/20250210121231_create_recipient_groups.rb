class CreateRecipientGroups < ActiveRecord::Migration[6.1]
  def change
    create_table :recipient_groups do |t|
      t.string :name
      t.string :origin_class_name
      t.string :origin_class_object_id
      t.string :access_method

      t.timestamps
    end
  end
end
