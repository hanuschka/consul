class AddPageContentCachedDataToProjekts < ActiveRecord::Migration[6.1]
  def change
    add_column :projekts, :cached_params_for_page_content, :json
  end
end
