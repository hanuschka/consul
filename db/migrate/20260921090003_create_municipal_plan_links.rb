class CreateMunicipalPlanLinks < ActiveRecord::Migration[6.1]
  def change
    create_table :municipal_plan_links do |t|
      t.bigint :municipal_plan_id, null: false
      t.string :title
      t.string :url
      t.integer :given_order

      t.timestamps
    end

    add_index :municipal_plan_links, :municipal_plan_id,
      name: "index_municipal_plan_links_on_plan_id"
  end
end
