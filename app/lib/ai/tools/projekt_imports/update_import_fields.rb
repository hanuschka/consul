class Ai::Tools::ProjektImports::UpdateImportFields < Ai::Tools::ProjektImports::EditorTool
  description "Updates top level fields of the project import. Every field must be " \
              "present in the call: send null for each field you are NOT changing and " \
              "it keeps its stored value. To clear a text field send an empty string, " \
              "not null. To clear a list send an empty array."

  params Ai::Tools::ProjektImports::EditableFieldsParamSchema.new

  def execute(**attributes)
    changed = editor.update_fields(attributes.stringify_keys)

    return { status: "no_changes" } if changed.empty?

    { status: "updated", changed_fields: changed }
  end
end
