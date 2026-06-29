class AddPdfFormatProgressToProjektEvaluations < ActiveRecord::Migration[6.1]
  def change
    add_column :projekt_evaluations, :pdf_format_progress, :jsonb, default: {}
  end
end
