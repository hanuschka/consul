class Projekts::ImportContentFromDocumentJob < ApplicationJob
  queue_as :default

  def perform(projekt_id)
    projekt = Projekt.find(projekt_id)
    text = projekt.build_file_import_data&.dig("text")

    begin
      projekt.update_column(:build_file_import_status, "processing")

      result = ProjektContentBlocks::BuildWithAi.call(text: text, projekt: projekt)

      if result.success?
        update_projekt_dates(projekt, result.projekt_start_date, result.projekt_end_date)
        update_projekt_categories(projekt, result.categories)
        valid_sdg_codes = update_projekt_sdgs(projekt, result.sdg_codes)
        content_blocks_data = create_content_blocks(projekt, result.blocks)

        projekt.update_columns(
          build_file_import_status: "completed",
          build_file_import_data: {
            content_blocks: content_blocks_data,
            categories: result.categories,
            sdg_codes: valid_sdg_codes
          }
        )
      else
        projekt.update_columns(
          build_file_import_status: "failed",
          build_file_import_data: { error: { message: result.error } }
        )
      end
    rescue => e
      projekt.update_columns(
        build_file_import_status: "failed",
        build_file_import_data: { error: { message: "Unerwarteter Fehler beim Import: #{e.message}" } }
      )
      raise e
    end
  end

  private

  def update_projekt_dates(projekt, start_date_str, end_date_str)
    updates = {}

    if start_date_str.present?
      begin
        updates[:total_duration_start] = Date.parse(start_date_str)
      rescue ArgumentError
      end
    end

    if end_date_str.present?
      begin
        updates[:total_duration_end] = Date.parse(end_date_str)
      rescue ArgumentError
      end
    end

    projekt.update(updates) if updates.any?
  end

  def update_projekt_categories(projekt, categories)
    return if categories.blank?

    projekt.tag_list.add(categories)
    projekt.save
  rescue => e
    Rails.logger.error("Failed to update projekt categories: #{e.message}")
  end

  def update_projekt_sdgs(projekt, sdg_codes)
    return [] if sdg_codes.blank?

    valid_codes = validate_sdg_codes(sdg_codes)
    return [] if valid_codes.blank?

    projekt.related_sdg_list = valid_codes.join(", ")
    projekt.save

    valid_codes
  rescue => e
    Rails.logger.error("Failed to update projekt SDGs: #{e.message}")
    []
  end

  def validate_sdg_codes(codes)
    codes.select do |code|
      if code.include?(".")
        SDG::Target.exists?(code: code) || SDG::LocalTarget.exists?(code: code)
      else
        SDG::Goal.exists?(code: code.to_i)
      end
    end
  end

  def create_content_blocks(projekt, blocks)
    blocks.map do |block_data|
      html = block_data['html']
      content_block = projekt.content_blocks.create!(
        name: "custom",
        body: html,
        key: "projekt_content_block_#{projekt.id}_#{projekt.content_blocks.count + 1}_#{DateTime.now.to_i}",
        locale: "de",
        margin_bottom: SiteCustomization::ContentBlock::DEFAULT_MARGIN_BOTTOM
      )
      { id: content_block.id, html: html }
    end
  end
end
