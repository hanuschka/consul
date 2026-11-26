require "rails_helper"

describe ProjektImports::OutputSchemaBuilder do
  def template_id_schema(schema)
    schema.dig(:properties, :content_blocks, :items, :properties, :template_id)
  end

  it "only accepts the template ids the prompt offered" do
    refs = { "content_block_templates" => [{ "id" => 4 }, { "id" => 25 }] }

    expect(template_id_schema(ProjektImports::OutputSchemaBuilder.build(refs))[:enum]).to eq [4, 25]
  end

  it "accepts any template id when no templates could be read" do
    schema = ProjektImports::OutputSchemaBuilder.build({ "content_block_templates" => [] })

    expect(template_id_schema(schema)).not_to have_key(:enum)
  end
end
