# Supplies update_import_fields with the same category and SDG enums the initial
# extraction is constrained by, so the chat cannot invent a tag the extraction
# step would have rejected. Resolved lazily for the same reason as
# PhaseParamSchema: the constant is read at class-body load, the DB is not.
class Ai::Tools::ProjektImports::EditableFieldsParamSchema
  NULLABLE_STRING = %w[string null].freeze

  def to_json_schema
    properties = {
      title: { type: NULLABLE_STRING, description: "Project title" },
      subtitle: { type: NULLABLE_STRING, description: "Project subtitle or tagline" },
      projekt_start_date: { type: NULLABLE_STRING, description: "ISO 8601 date (YYYY-MM-DD)" },
      projekt_end_date: { type: NULLABLE_STRING, description: "ISO 8601 date (YYYY-MM-DD)" },
      categories: nullable_list(::ProjektImports::OutputSchemaBuilder.categories_schema(refs)),
      sdg_codes: nullable_list(::ProjektImports::OutputSchemaBuilder.sdg_codes_schema(refs)),
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

  # Only the reference lists the enums need — ReferencesBuilder.build would also
  # make a DT HTTP call for content block templates this schema never uses.
  def refs
    @refs ||= {
      "tags" => ::ProjektImports::ReferencesBuilder.fetch_tags,
      "sdg_goals" => ::ProjektImports::ReferencesBuilder.fetch_sdg_goals
    }
  end

  def nullable_list(list_schema)
    list_schema.merge(
      type: %w[array null],
      description: "Complete replacement list, or null to leave unchanged"
    )
  end
end
