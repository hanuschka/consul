class AddRecipientGroupToNewsletters < ActiveRecord::Migration[6.1]
  def change
    add_reference :newsletters, :recipient_group, foreign_key: true
  end
end
