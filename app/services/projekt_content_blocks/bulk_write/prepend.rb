class ProjektContentBlocks::BulkWrite::Prepend < ApplicationService
  attr_reader :block_writer, :items

  def initialize(projekt:, items:)
    @block_writer = ProjektContentBlocks::BulkWrite::BlockWriter.new(projekt)
    @items = items
  end

  def call
    existing_blocks = block_writer.existing_blocks

    new_blocks =
      items.each_with_index.map do |item, index|
        block_writer.create(item, index)
      end

    block_writer.renumber(new_blocks + existing_blocks)

    new_blocks
  end
end
