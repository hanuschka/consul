class AddGeneratedImageToProposals < ActiveRecord::Migration[6.1]
  def change
    add_column :proposals, :generated_image, :boolean, default: false, null: false
  end
end
