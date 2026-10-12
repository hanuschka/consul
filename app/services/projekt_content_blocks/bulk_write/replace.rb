class ProjektContentBlocks::BulkWrite::Replace < ApplicationService
  attr_reader :block_writer, :items

  def initialize(projekt:, items:)
    @block_writer = ProjektContentBlocks::BulkWrite::BlockWriter.new(projekt)
    @items = items
  end

  def call
    listed_blocks_by_index = find_listed_blocks

    removed_blocks = block_writer.existing_blocks - listed_blocks_by_index.values
    block_writer.destroy_all(removed_blocks)

    ordered_blocks =
      items.each_with_index.map do |item, index|
        write(listed_blocks_by_index[index], item, index)
      end

    block_writer.renumber(ordered_blocks)

    ordered_blocks
  end

  private

  # Every id is resolved before anything is deleted, so an unknown id fails
  # the request without touching the existing blocks.
  def find_listed_blocks
    items.each_with_index.each_with_object({}) do |(item, index), listed_blocks_by_index|
      if item["id"].present?
        listed_blocks_by_index[index] = block_writer.find(item, index)
      end
    end
  end

  def write(listed_block, item, index)
    if listed_block.present?
      block_writer.update(listed_block, item, index)
    else
      block_writer.create(item, index)
    end
  end
end
