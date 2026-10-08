class ProjektContentBlocks::BulkWrite::BlockWriter
  ATTRIBUTES = %w[body visible visible_from visible_until margin_bottom].freeze

  attr_reader :projekt

  def initialize(projekt)
    @projekt = projekt
  end

  # Loaded once, before any write, so callers get the blocks as they were
  # when the request arrived.
  def existing_blocks
    @existing_blocks ||=
      SiteCustomization::ContentBlock
        .where(projekt_id: projekt.id)
        .includes(:translations)
        .order(:position)
        .to_a
  end

  def find(item, index)
    content_block = existing_blocks_by_id[item["id"].to_i]

    if content_block.present?
      return content_block
    end

    message =
      if item["id"].present?
        "Content block #{item["id"]} not found for this projekt"
      else
        "id is required"
      end

    raise_invalid(index, [message])
  end

  def create(item, index)
    content_block =
      projekt.content_blocks.build(
        name: "custom",
        locale: SiteCustomization::ContentBlock.canonical_locale,
        key: SiteCustomization::ContentBlock.generate_projekt_key(projekt.id, SecureRandom.hex(4)),
        body: ""
      )

    save(content_block, item, index)
  end

  def update(content_block, item, index)
    save(content_block, item, index)
  end

  def move(content_block, item, index)
    position = item["position"].to_i

    if position < 1
      raise_invalid(index, ["position must be 1 or greater"])
    end

    content_block.insert_at(position)
  end

  def renumber(content_blocks)
    content_block_ids = content_blocks.map(&:id)

    return if content_block_ids.empty?

    SiteCustomization::ContentBlock
      .where(id: content_block_ids)
      .update_all(["position = array_position(ARRAY[?]::integer[], id)", content_block_ids])
  end

  private

  def existing_blocks_by_id
    @existing_blocks_by_id ||= existing_blocks.index_by(&:id)
  end

  def save(content_block, item, index)
    content_block.assign_attributes(attributes_from(item))

    return content_block if content_block.save

    raise_invalid(index, content_block.errors.full_messages)
  end

  # visible is NOT NULL in the database, so a null from the client means
  # "leave it as it is" rather than a value to write.
  def attributes_from(item)
    item
      .slice(*ATTRIBUTES)
      .reject { |attribute, value| attribute == "visible" && value.nil? }
  end

  def raise_invalid(index, messages)
    raise ProjektContentBlocks::BulkWrite::InvalidRequestError.new(
      "content_blocks[#{index}]" => messages
    )
  end
end
