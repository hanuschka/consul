class ProjektImports::AiResultEditor
  SCALAR_FIELDS = %w[
    title subtitle projekt_start_date projekt_end_date image_prompt
  ].freeze

  COLLECTION_FIELDS = %w[categories sdg_codes].freeze

  class IndexError < StandardError; end

  attr_reader :projekt_import

  def initialize(projekt_import:)
    @projekt_import = projekt_import
  end

  def overview
    data.slice(*(SCALAR_FIELDS + COLLECTION_FIELDS)).merge(
      "phase_count" => phases.size,
      "content_block_count" => Array(data["content_blocks"]).size
    )
  end

  def phases
    Array(data["phases"])
  end

  def content_blocks
    Array(data["content_blocks"])
  end

  def update_fields(attributes)
    changed = attributes.compact.slice(*(SCALAR_FIELDS + COLLECTION_FIELDS))
    return [] if changed.empty?

    write(data.merge(changed))

    changed.keys
  end

  def replace_phase(phase_index, phase)
    updated = phases
    ensure_index!(phase_index, updated)
    updated[phase_index] = phase

    write(data.merge("phases" => updated))

    phase_index
  end

  def add_phase(phase)
    updated = phases + [phase]

    write(data.merge("phases" => updated))

    updated.size - 1
  end

  def remove_phase(phase_index)
    updated = phases
    ensure_index!(phase_index, updated)
    removed = updated.delete_at(phase_index)

    write(data.merge("phases" => updated))

    removed
  end

  def replace_content_blocks(blocks)
    write(data.merge("content_blocks" => Array(blocks)))

    blocks.size
  end

  private

  def data
    projekt_import.ai_result.presence || {}
  end

  def write(updated_data)
    projekt_import.update!(ai_result: updated_data)
  end

  def ensure_index!(phase_index, collection)
    return if phase_index.is_a?(Integer) && phase_index >= 0 && phase_index < collection.size

    raise IndexError, "phase_index #{phase_index} is out of range (0..#{collection.size - 1})"
  end
end
