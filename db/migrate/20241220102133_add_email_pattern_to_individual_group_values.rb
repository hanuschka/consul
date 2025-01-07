class AddEmailPatternToIndividualGroupValues < ActiveRecord::Migration[6.1]
  def change
    add_column :individual_group_values, :email_pattern, :string, null: false, default: ""
  end
end
