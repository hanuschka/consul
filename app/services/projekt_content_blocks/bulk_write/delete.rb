class ProjektContentBlocks::BulkWrite::Delete < ApplicationService
  attr_reader :block_writer, :items

  def initialize(projekt:, items:)
    @block_writer = ProjektContentBlocks::BulkWrite::BlockWriter.new(projekt)
    @items = items
  end

  def call
    content_blocks =
      items.each_with_index.map do |item, index|
        block_writer.find(item, index)
      end

    content_blocks.uniq.each(&:destroy!)
  end
end
