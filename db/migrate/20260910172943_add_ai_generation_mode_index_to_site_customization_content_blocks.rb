class AddAiGenerationModeIndexToSiteCustomizationContentBlocks < ActiveRecord::Migration[6.1]
  def change
    add_index :site_customization_content_blocks,
      "((ai_generation_data ->> 'mode'::text)), ((ai_generation_data ->> 'status'::text))",
      name: "index_site_customization_content_blocks_on_ai_mode_and_status"
  end
end
