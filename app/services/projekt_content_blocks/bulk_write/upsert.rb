class ProjektContentBlocks::BulkWrite::Upsert < ApplicationService
  attr_reader :block_writer, :items

  def initialize(projekt:, items:)
    @block_writer = ProjektContentBlocks::BulkWrite::BlockWriter.new(projekt)
    @items = items
  end

  def call
    items.each_with_index.map do |item, index|
      content_block = write(item, index)

      if item["position"].present?
        block_writer.move(content_block, item, index)
      end

      content_block
    end
  end

  private

  def write(item, index)
    if item["id"].present?
      block_writer.update(block_writer.find(item, index), item, index)
    else
      block_writer.create(item, index)
    end
  end
end
