# Prints every LLM tool's wire definition — name, description and the JSON
# Schema of its parameters, as RubyLlmToolToOpenAiConverter hands them to the
# provider — sorted by name, as one JSON document.
#
# For proving a ruby_llm upgrade sends the same tools: no spec covers the
# schema DSL, so dump before and after and diff the two files.
#
#   bin/rails runner lib/scripts/ai/dump_tool_schemas.rb > before.json
#   bin/rails runner lib/scripts/ai/dump_tool_schemas.rb > after.json
#   diff <(jq -S . before.json) <(jq -S . after.json)
require "json"

whatsapp_tool_classes = (
  Whatsapp::AiAssistant::RouterService::READ_TOOLS +
  Whatsapp::AiAssistant::RouterService::WRITE_TOOLS +
  Whatsapp::AiAssistant::RouterService::DRAFT_TOOLS +
  Whatsapp::AiAssistant::RouterService::SEND_TOOLS
).uniq

projekt_import_tool_classes = [
  Ai::Tools::ProjektImports::AddImportPhase,
  Ai::Tools::ProjektImports::ReadImportData,
  Ai::Tools::ProjektImports::ReadSourceDocument,
  Ai::Tools::ProjektImports::RemoveImportPhase,
  Ai::Tools::ProjektImports::ReplaceImportPhase,
  Ai::Tools::ProjektImports::SetImportContentBlocks,
  Ai::Tools::ProjektImports::UpdateImportFields
]

tools =
  whatsapp_tool_classes.map { |tool_class| tool_class.new(conversation: nil) } +
  projekt_import_tool_classes.map { |tool_class| tool_class.new(editor: nil) } +
  [Ai::Tools::FetchContentBlockTemplates.new(templates_by_category: [])]

definitions = RubyLlmToolToOpenAiConverter.definitions_for(tools).sort_by { |definition| definition[:name] }

puts JSON.pretty_generate(definitions)
