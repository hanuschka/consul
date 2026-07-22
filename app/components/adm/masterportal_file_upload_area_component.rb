class Adm::MasterportalFileUploadAreaComponent < ApplicationComponent
  def max_file_size_bytes
    Masterportal::GeojsonFileFeatures::MAX_FILE_SIZE
  end

  def max_file_size_mb
    max_file_size_bytes / 1.megabyte
  end

  def accept_attribute
    ".json,.geojson,application/json,application/geo+json"
  end

  def js_config
    {
      maxFileSize: max_file_size_bytes,
      labels: {
        remove: t(".remove"),
        fromFile: t(".from_file"),
        nameLabel: t(".name_label"),
        nameHint: t(".name_hint"),
        namePlaceholder: t(".name_placeholder")
      },
      errors: {
        too_large: t(".errors.too_large", size: max_file_size_mb),
        invalid_type: t(".errors.invalid_type"),
        invalid_json: t(".errors.invalid_json"),
        not_feature_collection: t(".errors.not_feature_collection"),
        empty: t(".errors.empty"),
        duplicate_name: t(".errors.duplicate_name"),
        name_taken: t(".errors.name_taken"),
        generic: t(".errors.generic")
      }
    }
  end
end
