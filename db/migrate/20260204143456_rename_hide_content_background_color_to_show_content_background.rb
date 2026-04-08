class RenameHideContentBackgroundColorToShowContentBackground < ActiveRecord::Migration[6.1]
  def change
    rename_column :projekts, :hide_content_background_color, :show_content_background
    change_column_default :projekts, :show_content_background, from: false, to: true
    
    reversible do |dir|
      dir.up do
        execute "UPDATE projekts SET show_content_background = NOT show_content_background"
      end
      dir.down do
        execute "UPDATE projekts SET show_content_background = NOT show_content_background"
      end
    end
  end
end
