class Projekts::ImportFromFile < ApplicationService
  attr_reader :projekt, :file

  def initialize(projekt:, file:)
    @projekt = projekt
    @file = file
  end

  def call
    Rails.logger.info("[ImportFromFile] Starting document import for Projekt ##{projekt.id}")

    extraction_result = ProjektContentBlocks::DocumentTextExtractor.call(file: file)

    unless extraction_result.success?
      Rails.logger.error("[ImportFromFile] Text extraction failed for Projekt ##{projekt.id}: #{extraction_result.error}")
      return ServiceResult.failure(
        error: extraction_result.error,
        fallback_text: nil
      )
    end

    text = extraction_result.text
    Rails.logger.info("[ImportFromFile] Text extracted successfully for Projekt ##{projekt.id}, length: #{text.length} characters")

    parsing_result = ProjektContentBlocks::ImportWithAi.call(
      text: text,
      projekt: projekt
    )

    if parsing_result.success?
      Rails.logger.info("[ImportFromFile] AI parsing successful for Projekt ##{projekt.id}")
      update_projekt_dates(
        parsing_result.projekt_start_date,
        parsing_result.projekt_end_date
      )
      Rails.logger.info("[ImportFromFile] Projekt dates updated for Projekt ##{projekt.id}")

      result = create_content_blocks_from_structure(parsing_result.blocks)
      Rails.logger.info("[ImportFromFile] Content blocks created for Projekt ##{projekt.id}")
      result
    else
      Rails.logger.error("[ImportFromFile] AI parsing failed for Projekt ##{projekt.id}: #{parsing_result.error}")
      ServiceResult.failure(
        error: parsing_result.error,
        fallback_text: text
      )
    end
  rescue => e
    Rails.logger.error("[ImportFromFile] Unexpected error for Projekt ##{projekt.id}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    ServiceResult.failure(
      error: "Unerwarteter Fehler: #{e.message}",
      fallback_text: nil
    )
  end

  private

  def update_projekt_dates(start_date_str, end_date_str)
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

  def create_content_blocks_from_structure(blocks)
    content_blocks_data = blocks.map do |block_data|
      create_content_block(block_data['html'])
    end

    ServiceResult.success(content_blocks_data: content_blocks_data)
  end

  def create_content_block(html)
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
