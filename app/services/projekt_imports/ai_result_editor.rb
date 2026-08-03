class ProjektImports::AiResultEditor
  EDITABLE_FIELDS = %w[
    title subtitle projekt_start_date projekt_end_date image_prompt
    categories sdg_codes
  ].freeze

  class IndexError < StandardError; end
  class ResolvedContentBlocksError < StandardError; end

  attr_reader :projekt_import, :journal

  def initialize(projekt_import:, journal:)
    @projekt_import = projekt_import
    @journal = journal
  end

  def overview
    data.slice(*EDITABLE_FIELDS).merge(
      "phase_count" => Array(data["phases"]).size,
      "content_block_count" => Array(data["content_blocks"]).size
    )
  end

  # Array() is the identity function for an Array, so these would otherwise hand
  # out the live ai_result arrays and let callers mutate the attribute in place
  # before the save. A failed update! would then leave the in-memory record
  # showing changes the database never took.
  def phases
    Array(data["phases"]).dup
  end

  def content_blocks
    Array(data["content_blocks"]).dup
  end

  def update_fields(attributes)
    changed = attributes.compact.slice(*EDITABLE_FIELDS)
    return [] if changed.empty?

    write(data.merge(changed), "update_fields", fields: changed.keys)

    changed.keys
  end

  def replace_phase(phase_index, phase)
    updated = phases
    ensure_index!(phase_index, updated)
    updated[phase_index] = phase

    write(data.merge("phases" => updated), "replace_phase", phase_index: phase_index)

    phase_index
  end

  def add_phase(phase)
    updated = phases + [phase]

    write(data.merge("phases" => updated), "add_phase", phase_index: updated.size - 1, type: phase["type"])

    updated.size - 1
  end

  def remove_phase(phase_index)
    updated = phases
    ensure_index!(phase_index, updated)
    removed = updated.delete_at(phase_index)

    write(data.merge("phases" => updated), "remove_phase", type: removed["type"])

    removed
  end

  # ResolveContentBlocksService rewrites stored blocks from {template_id,
  # content_data} to {html} and persists that, so once an import has run the
  # template form is gone and writing it back would mix two shapes.
  def replace_content_blocks(blocks)
    if content_blocks.any? { |block| block.key?("html") }
      raise ResolvedContentBlocksError,
        "content blocks were already rendered to HTML by a previous import and " \
        "can no longer be edited here"
    end

    write(data.merge("content_blocks" => Array(blocks)), "replace_content_blocks", count: blocks.size)

    blocks.size
  end

  private

  def data
    projekt_import.ai_result.presence || {}
  end

  # One commit for the edit and its journal entry: an edit that persisted without
  # its entry is exactly the state a retry would replay.
  def write(updated_data, action, details)
    ActiveRecord::Base.transaction do
      projekt_import.update!(ai_result: updated_data)
      journal.record(action, details)
    end
  end

  def ensure_index!(phase_index, collection)
    return if phase_index.is_a?(Integer) && phase_index >= 0 && phase_index < collection.size

    raise IndexError, "phase_index #{phase_index} is out of range (0..#{collection.size - 1})"
  end
end
