class AddOfficialAnswerToProposals < ActiveRecord::Migration[6.1]
  def change
    add_column :proposals, :official_answer, :text, default: ""
  end
end
