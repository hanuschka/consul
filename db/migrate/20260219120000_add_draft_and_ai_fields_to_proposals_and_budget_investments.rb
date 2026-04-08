class AddDraftAndAiFieldsToProposalsAndBudgetInvestments < ActiveRecord::Migration[6.1]
  def change
    add_column :proposals, :draft, :boolean, default: false, null: false
    add_column :proposals, :ai_idea_text, :text
    add_column :proposals, :ai_evaluation_result, :jsonb
    add_column :proposals, :ai_image_prompt, :text
    add_index :proposals, :draft

    add_column :budget_investments, :draft, :boolean, default: false, null: false
    add_column :budget_investments, :ai_idea_text, :text
    add_column :budget_investments, :ai_evaluation_result, :jsonb
    add_column :budget_investments, :ai_image_prompt, :text
    add_index :budget_investments, :draft
  end
end
