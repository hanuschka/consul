class ChangeDefaultNewsletterinUsers < ActiveRecord::Migration[6.1]
  def change
    change_column_default :users, :newsletter, from: true, to: false
  end
end
