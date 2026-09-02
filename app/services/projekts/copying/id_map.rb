class Projekts::Copying::IdMap
  def initialize
    @record_ids = {}
    @blob_keys = {}
  end

  def register(source_record, copy_record)
    register_source(base_name(source_record), source_record.id, copy_record)
  end

  # The cross-instance import has no source record to read a class off -- it
  # rebuilds from a serialized node, so it names the model and the source id
  # itself. Both paths write the same key, so the readers stay identical.
  def register_source(model_name, source_id, copy_record)
    return if source_id.blank?

    @record_ids[[model_name, source_id]] = copy_record.id
  end

  def register_blob(source_blob, copy_blob)
    @blob_keys[source_blob.key] = copy_blob.key
  end

  def copy_id_for(model_class, source_id)
    return nil if source_id.blank?

    @record_ids[[model_class.base_class.name, source_id]]
  end

  attr_reader :blob_keys

  private

    def base_name(record)
      record.class.base_class.name
    end
end
