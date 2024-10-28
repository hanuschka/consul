class AddOpenEndedToProjektEvents < ActiveRecord::Migration[6.1]
  def change
    add_column :projekt_events, :open_ended, :boolean, default: false
  end
end
