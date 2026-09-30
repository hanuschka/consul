class CreateMunicipalPlanNotices < ActiveRecord::Migration[6.1]
  def change
    create_table :municipal_plan_notices do |t|
      t.references :municipal_plan, null: false, foreign_key: true, index: true
      t.string :name
      t.string :email, null: false
      t.text :body, null: false

      t.timestamps
    end
  end
end
