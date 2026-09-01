class AddCompanyNameToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :company_name, :string
  end
end
