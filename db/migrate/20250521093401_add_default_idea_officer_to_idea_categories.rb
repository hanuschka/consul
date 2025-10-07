class AddDefaultIdeaOfficerToIdeaCategories < ActiveRecord::Migration[6.1]
  def change
    add_reference :idea_categories, :idea_officer, foreign_key: true, index: true
  end
end
