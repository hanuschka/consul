class RemoveNullConstrainFromSegmentRecipientInNewsletters < ActiveRecord::Migration[6.1]
  def change
    change_column_null :newsletters, :segment_recipient, null: false
  end
end
