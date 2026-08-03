# Supplies the phase tools with the same phase schema the initial extraction
# uses. RubyLLM resolves #to_json_schema lazily, so the ProjektPhase constant is
# only touched when a tool is first invoked, never while the class tree loads.
class Ai::Tools::ProjektImports::PhaseParamSchema
  INDEX_PROPERTY = {
    phase_index: {
      type: "integer",
      description: "Zero based index of the phase, as returned by read_import_data"
    }
  }.freeze

  def self.with_index
    new(extra_properties: INDEX_PROPERTY)
  end

  def self.without_index
    new(extra_properties: {})
  end

  def initialize(extra_properties:)
    @extra_properties = extra_properties
  end

  def to_json_schema
    properties = @extra_properties.merge(phase: phase_schema)

    {
      type: "object",
      properties: properties,
      required: properties.keys.map(&:to_s),
      additionalProperties: false
    }
  end

  private

  def phase_schema
    ProjektImports::OutputSchemaBuilder.phase_item_schema(ProjektPhase::PROJEKT_PHASES_TYPES)
  end
end
