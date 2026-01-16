class Projekts::BuildFromDocument < ApplicationService
  attr_reader :projekt, :file

  def initialize(projekt:, file:)
    @projekt = projekt
    @file = file
  end

  def call
    extraction_result = ProjektContentBlocks::DocumentTextExtractor.call(file: file)

    unless extraction_result.success?
      return ServiceResult.failure(
        error: extraction_result.error,
        fallback_text: nil
      )
    end

    text = extraction_result.text

    parsing_result = ProjektContentBlocks::BuildWithAi.call(
      text: text,
      projekt: projekt
    )

    if parsing_result.success?
      update_projekt_dates(
        parsing_result.projekt_start_date,
        parsing_result.projekt_end_date
      )
      create_content_blocks_from_structure(parsing_result.blocks)
    else
      ServiceResult.failure(
        error: parsing_result.error,
        fallback_text: text
      )
    end
  rescue => e
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
