# Supplies the editable top level fields of a project import to
# update_import_fields.
#
# Categories and SDG codes are advertised as plain strings rather than as the
# enum the initial extraction uses. RubyLLM memoizes a tool's JSON schema on a
# class level SchemaDefinition for the life of the process
# (RubyLLM::Tool.params + SchemaDefinition#json_schema), so an enum resolved
# here would freeze at worker boot: a category added afterwards could never be
# set from the chat until the worker restarted. UpdateImportFields validates
# both lists against the current records on every call instead.
class Ai::Tools::ProjektImports::EditableFieldsParamSchema
  NULLABLE_STRING = %w[string null].freeze

  def to_json_schema
    properties = {
      title: { type: NULLABLE_STRING, description: "Project title" },
      subtitle: { type: NULLABLE_STRING, description: "Project subtitle or tagline" },
      projekt_start_date: { type: NULLABLE_STRING, description: "ISO 8601 date (YYYY-MM-DD)" },
      projekt_end_date: { type: NULLABLE_STRING, description: "ISO 8601 date (YYYY-MM-DD)" },
      categories: nullable_list("Category names. Must already exist on this " \
                                "platform; the tool reports the unknown ones back " \
                                "if you send a name that does not."),
      sdg_codes: nullable_list("SDG goal codes that already exist on this platform."),
      image_prompt: { type: NULLABLE_STRING, description: "English prompt for AI image generation" }
    }

    {
      type: "object",
      properties: properties,
      required: properties.keys.map(&:to_s),
      additionalProperties: false
    }
  end

  private

  def nullable_list(description)
    {
      type: %w[array null],
      items: { type: "string" },
      description: "#{description} Complete replacement list, or null to leave unchanged."
    }
  end
end
