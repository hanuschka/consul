class AddEmbeddedPageViewCodeToProjekts < ActiveRecord::Migration[5.2]
  def change
    add_column :projekts, :embedded_page_view_code, :string
  end
end
