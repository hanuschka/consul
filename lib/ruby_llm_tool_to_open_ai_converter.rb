# Turns RubyLLM::Tool objects into the function definitions OpenAI's Responses
# API takes. Kept out of any one transport because the tools are ruby_llm's and
# the wire format is OpenAI's, so this belongs to neither: a caller assembles
# its tools, converts them here, and hands the definitions to whatever is
# talking to the provider.
module RubyLlmToolToOpenAiConverter
  # ruby_llm's schema DSL writes its own `strict` flag into the parameters
  # object. It is not a JSON Schema keyword and means nothing there — the
  # provider takes strictness from the definition around the schema — so it is
  # dropped rather than forwarded. Chat Completions ignored it; leaving it in
  # place would turn the eventual move to strict mode into a puzzling refusal.
  NON_SCHEMA_KEYS = %w[strict].freeze

  def self.definitions_for(tools)
    tools.map { |tool| definition_for(tool) }
  end

  # The Responses API puts a function's name, description and parameters at the
  # top level of the definition, where Chat Completions nests them under
  # `function`.
  #
  # Left unstrict to match what ruby_llm sent these tools with. A schema from
  # the `params` DSL does qualify for strict mode — every property is listed
  # in `required` and an optional one is a nullable `anyOf` rather than a
  # missing key — so turning it on is one word here, and a change in how the
  # model is constrained rather than a change of transport.
  def self.definition_for(tool)
    {
      type: "function",
      name: tool.name,
      description: tool.description,
      parameters: parameters_for(tool),
      strict: false
    }
  end

  # ruby_llm always has a schema to give: the `params` DSL's, one derived from
  # the older `param` declarations, or one inferred from #execute's keywords
  # for a tool that declares neither — an argumentless tool included, which
  # gets the empty object schema the provider requires. So there is nothing to
  # fall back to, and a version that did hand back nothing would raise here
  # rather than quietly tell the model the tool takes no arguments.
  def self.parameters_for(tool)
    tool.params_schema.reject { |key, _| NON_SCHEMA_KEYS.include?(key.to_s) }
  end
end
