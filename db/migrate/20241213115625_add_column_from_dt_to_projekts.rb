class AddColumnFromDtToProjekts < ActiveRecord::Migration[6.1]
  def change
    add_column :projekts, :from_dt, :boolean, default: false
  end
end
