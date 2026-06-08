class AddPdfFormatFieldsToProjektEvaluations < ActiveRecord::Migration[6.1]
  def change
    add_column :projekt_evaluations, :pdf_formatted_html, :text
    add_column :projekt_evaluations, :pdf_formatted_status, :string
    add_column :projekt_evaluations, :pdf_formatted_at, :datetime
    add_column :projekt_evaluations, :pdf_formatted_data_fingerprint, :string
    add_column :projekt_evaluations, :pdf_formatted_error, :string

    add_index :projekt_evaluations,
      [:projekt_id, :pdf_formatted_status],
      name: "index_projekt_evaluations_on_projekt_id_and_pdf_status"
  end
end
