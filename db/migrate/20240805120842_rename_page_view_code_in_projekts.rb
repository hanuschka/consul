class RenamePageViewCodeInProjekts < ActiveRecord::Migration[6.1]
  def change
    rename_column :projekts, :page_view_code, :frame_access_code
    add_column :projekts, :preview_code, :string
  end
end
