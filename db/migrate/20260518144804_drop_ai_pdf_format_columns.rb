class DropAiPdfFormatColumns < ActiveRecord::Migration[6.1]
  def up
    remove_index :projekt_evaluations,
      name: "index_projekt_evaluations_on_projekt_id_and_pdf_status",
      if_exists: true

    remove_column :projekt_evaluations, :pdf_formatted_html, if_exists: true
    remove_column :projekt_evaluations, :pdf_formatted_status, if_exists: true
    remove_column :projekt_evaluations, :pdf_formatted_at, if_exists: true
    remove_column :projekt_evaluations, :pdf_formatted_data_fingerprint, if_exists: true
    remove_column :projekt_evaluations, :pdf_formatted_error, if_exists: true
    remove_column :projekt_evaluations, :pdf_format_progress, if_exists: true

    remove_column :projekt_phase_evaluations, :pdf_formatted_html, if_exists: true
    remove_column :projekt_phase_evaluations, :pdf_formatted_status, if_exists: true
    remove_column :projekt_phase_evaluations, :pdf_formatted_at, if_exists: true
    remove_column :projekt_phase_evaluations, :pdf_formatted_data_fingerprint, if_exists: true
    remove_column :projekt_phase_evaluations, :pdf_formatted_error, if_exists: true
  end

  def down
    add_column :projekt_evaluations, :pdf_formatted_html, :text
    add_column :projekt_evaluations, :pdf_formatted_status, :string
    add_column :projekt_evaluations, :pdf_formatted_at, :datetime
    add_column :projekt_evaluations, :pdf_formatted_data_fingerprint, :string
    add_column :projekt_evaluations, :pdf_formatted_error, :string
    add_column :projekt_evaluations, :pdf_format_progress, :jsonb, default: {}

    add_index :projekt_evaluations,
      [:projekt_id, :pdf_formatted_status],
      name: "index_projekt_evaluations_on_projekt_id_and_pdf_status"

    add_column :projekt_phase_evaluations, :pdf_formatted_html, :text
    add_column :projekt_phase_evaluations, :pdf_formatted_status, :string
    add_column :projekt_phase_evaluations, :pdf_formatted_at, :datetime
    add_column :projekt_phase_evaluations, :pdf_formatted_data_fingerprint, :string
    add_column :projekt_phase_evaluations, :pdf_formatted_error, :string
  end
end
