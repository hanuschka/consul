class ContentBlockSerializer < BaseSerializer
  attr_reader :content_block

  def initialize(content_block)
    @content_block = content_block
  end

  def serialize
    content_block.as_json(
      only: [
        :id,
        :name,
        :locale,
        :body,
        :key,
        :projekt_id,
        :position,
        :created_at,
        :updated_at
      ]
    )
  end

  def self.serialize_collection(content_blocks)
    content_blocks.map { |block| new(block).serialize }
  end
end

