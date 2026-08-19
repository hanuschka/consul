module Ai::OpenaiSdk::ToolDefinitions
  # A tool that takes no arguments still owes the provider an object schema.
  NO_PARAMETERS = {
    "type" => "object",
    "properties" => {},
    "required" => [],
    "additionalProperties" => false
  }.freeze

  # ruby_llm's schema DSL writes its own `strict` flag into the parameters
  # object. It is not a JSON Schema keyword and means nothing there — the
  # provider takes strictness from the definition around the schema — so it is
  # dropped rather than forwarded. Chat Completions ignored it; leaving it in
  # place would turn the eventual move to strict mode into a puzzling refusal.
  NON_SCHEMA_KEYS = %w[strict].freeze

  # The Responses API puts a function's name, description and parameters at the
  # top level of the definition, where Chat Completions nests them under
  # `function`. The schema itself is the one ruby_llm's `params` DSL already
  # derives from these tool classes, so a parameter is still described in one
  # place — the tool — and no schema is maintained twice.
  #
  # Left unstrict to match what these tools were sent with before. The schemas
  # do qualify for strict mode — every property is listed in `required` and an
  # optional one is a nullable `anyOf` rather than a missing key — so turning it
  # on later is one word here, and a change in how the model is constrained
  # rather than a change of transport.
  def self.build(tools)
    tools.map do |tool|
      {
        type: "function",
        name: tool.name,
        description: tool.description,
        parameters: parameters_for(tool),
        strict: false
      }
    end
  end

  def self.parameters_for(tool)
    schema = tool.params_schema

    return NO_PARAMETERS if schema.blank?

    schema.reject { |key, _| NON_SCHEMA_KEYS.include?(key.to_s) }
  end
end
