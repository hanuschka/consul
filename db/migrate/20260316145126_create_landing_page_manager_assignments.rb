class CreateLandingPageManagerAssignments < ActiveRecord::Migration[6.1]
  def change
    create_table :landing_page_manager_assignments do |t|
      t.references :landing_page_manager, foreign_key: true, index: { name: "idx_lpm_assignments_on_manager_id" }
      t.references :page, foreign_key: { to_table: :site_customization_pages }, index: { name: "idx_lpm_assignments_on_page_id" }

      t.timestamps
    end
  end
end
