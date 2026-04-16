class CreateSiteCustomizationEmailTemplates < ActiveRecord::Migration[6.1]
  def change
    create_table :site_customization_email_templates do |t|
      t.references :projekt_phase, null: true, foreign_key: { to_table: :projekt_phases }
      t.string :mailer_class, null: false
      t.string :mailer_action, null: false
      t.string :locale, null: false, default: "de"
      t.string :subject
      t.text :body

      t.timestamps
    end

    add_index :site_customization_email_templates,
              [:projekt_phase_id, :mailer_class, :mailer_action, :locale],
              unique: true,
              name: "idx_email_templates_on_phase_mailer_action_locale"
  end
end
