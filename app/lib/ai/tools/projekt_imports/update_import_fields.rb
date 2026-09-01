class Ai::Tools::ProjektImports::UpdateImportFields < Ai::Tools::ProjektImports::EditorTool
  description "Updates top level fields of the project import. Every field must be " \
              "present in the call: send null for each field you are NOT changing and " \
              "it keeps its stored value. To clear a text field send an empty string, " \
              "not null. To clear a list send an empty array."

  params Ai::Tools::ProjektImports::EditableFieldsParamSchema.new

  AVAILABLE_VALUES_LIMIT = 100

  def execute(**attributes)
    unknown = unknown_reference_values(attributes)

    return { error: unknown_values_error(unknown) } if unknown.any?

    changed = editor.update_fields(attributes.stringify_keys)

    return { status: "no_changes" } if changed.empty?

    { status: "updated", changed_fields: changed }
  end

  private

  # Checked per call rather than through a schema enum — see
  # EditableFieldsParamSchema for why an enum cannot stay current here. Unknown
  # categories would otherwise be created as new tags by acts_as_taggable when
  # the projekt is built.
  def unknown_reference_values(attributes)
    {
      "categories" => unknown_tag_names(attributes[:categories]),
      "sdg_codes" => unknown_sdg_codes(attributes[:sdg_codes])
    }.reject { |_field, values| values.empty? }
  end

  def unknown_tag_names(values)
    names = normalized_values(values)
    return [] if names.empty?

    names - Tag.where(name: names).pluck(:name)
  end

  def unknown_sdg_codes(values)
    codes = normalized_values(values)
    return [] if codes.empty?
    return [] if !sdg_goals_available?

    codes - SDG::Goal.where(code: codes).pluck(:code).map(&:to_s)
  end

  def normalized_values(values)
    Array(values).map { |value| value.to_s.strip }.compact_blank.uniq
  end

  def sdg_goals_available?
    SDG::Goal.exists?
  rescue NameError
    false
  end

  def unknown_values_error(unknown)
    details = unknown.map do |field, values|
      "#{field}: #{values.join(', ')} (available: #{available_values_for(field)})"
    end

    "Nothing was saved. These values do not exist on this platform — " \
      "#{details.join('; ')}. Retry with existing values or ask the user which " \
      "to use."
  end

  def available_values_for(field)
    case field
    when "categories"
      Tag.order(:name).limit(AVAILABLE_VALUES_LIMIT).pluck(:name).join(", ")
    when "sdg_codes"
      SDG::Goal.order(:code).pluck(:code).join(", ")
    end
  end
end
