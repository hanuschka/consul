class RemoveCachedParamsForPageContentFromProjekts < ActiveRecord::Migration[6.1]
  def change
    remove_column :projekts, :cached_params_for_page_content
  end
end
