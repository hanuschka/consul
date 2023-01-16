class AddSummaryToProjektEvents < ActiveRecord::Migration[5.2]
  def change
    add_column :projekt_events, :summary, :string
  end
end
