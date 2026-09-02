class CreateDeficiencyReportSubcategories < ActiveRecord::Migration[6.1]
  def change
    create_table :deficiency_report_subcategories do |t|
      t.bigint :deficiency_report_category_id, null: false
      t.integer :given_order
      t.string :default_responsible_type
      t.bigint :default_responsible_id

      t.timestamps

      t.index [:deficiency_report_category_id], name: "index_dr_subcategories_on_category_id"
      t.index [:default_responsible_type, :default_responsible_id],
        name: "index_dr_subcategories_on_default_responsible"
    end

    add_foreign_key :deficiency_report_subcategories, :deficiency_report_categories,
      column: :deficiency_report_category_id

    add_reference :deficiency_reports, :deficiency_report_subcategory,
      foreign_key: true, index: { name: "index_deficiency_reports_on_subcategory_id" }

    reversible do |dir|
      dir.up do
        DeficiencyReport::Subcategory.create_translation_table! name: :string
      end

      dir.down do
        DeficiencyReport::Subcategory.drop_translation_table!
      end
    end
  end
end
