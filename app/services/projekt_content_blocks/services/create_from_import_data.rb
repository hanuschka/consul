class ProjektContentBlocks::Services::CreateFromImportData < ApplicationService
  attr_reader :projekt, :blocks, :locale

  def initialize(projekt:, blocks:, locale:)
    @projekt = projekt
    @blocks = Array(blocks)
    @locale = locale
  end

  def call
    offset = projekt.content_blocks.count

    ActiveRecord::Base.transaction do
      blocks.each_with_index.map do |block, index|
        body = block["html"].presence || block["content_data"].to_s
        next if body.blank?

        position = offset + index + 1

        begin
          content_block = projekt.content_blocks.create!(
            name: "custom",
            key: "projekt_content_block_#{projekt.id}_#{position}_#{DateTime.now.to_i}",
            body: body,
            locale: locale,
            position: position
          )
        rescue ActiveRecord::RecordInvalid => e
          raise "content_block(##{position}): #{e.message}"
        end

        { id: content_block.id, html: body }
      end.compact
    end
  end
end
