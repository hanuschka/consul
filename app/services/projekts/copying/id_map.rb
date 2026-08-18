class Projekts::Copying::IdMap
  def initialize
    @record_ids = {}
    @blob_keys = {}
  end

  def register(source_record, copy_record)
    @record_ids[[base_name(source_record), source_record.id]] = copy_record.id
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
