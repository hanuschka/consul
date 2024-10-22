class RenameEmbededPageViewCodeToPageViewCodeInProjekts < ActiveRecord::Migration[6.1]
  def change
    rename_column :projekts, :embedded_page_view_code, :page_view_code
  end
end
