class ProjektContentBlocks::BulkWrite::Append < ApplicationService
  attr_reader :block_writer, :items

  def initialize(projekt:, items:)
    @block_writer = ProjektContentBlocks::BulkWrite::BlockWriter.new(projekt)
    @items = items
  end

  def call
    items.each_with_index.map do |item, index|
      block_writer.create(item, index)
    end
  end
end
