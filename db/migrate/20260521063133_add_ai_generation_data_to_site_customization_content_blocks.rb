class AddAiGenerationDataToSiteCustomizationContentBlocks < ActiveRecord::Migration[6.1]
  def change
    add_column :site_customization_content_blocks, :ai_generation_data, :jsonb

    add_index :site_customization_content_blocks,
              "((ai_generation_data->>'status'))",
              name: "index_site_customization_content_blocks_on_ai_status"
  end
end
