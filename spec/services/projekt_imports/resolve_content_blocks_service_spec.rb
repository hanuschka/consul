require "rails_helper"

describe ProjektImports::ResolveContentBlocksService do
  let(:projekt) { create(:projekt) }
  let(:projekt_import) { create(:projekt_import, status: "submitting", ai_result: { "content_blocks" => blocks }) }

  def resolve
    ProjektImports::ResolveContentBlocksService.call(projekt_import: projekt_import, projekt: projekt)
  end

  before do
    allow(ProjektImports::ResolveContentBlockHtmlService).to receive(:call) do |blocks:, **|
      ServiceResult.success(
        blocks: blocks.map { |block| { "html" => "<p>#{block['content_data']}</p>" } },
        unused_image_urls: [],
        templates_available: true
      )
    end
  end

  context "with blocks still in template form" do
    let(:blocks) do
      [
        { "template_id" => 25, "content_data" => "Intro" },
        { "template_id" => 4, "content_data" => "Body" }
      ]
    end

    it "records the template sequence on the projekt before the blocks are rendered to HTML" do
      resolve

      expect(projekt.reload.imported_content_block_template_ids).to eq [25, 4]
      expect(projekt_import.reload.ai_result["content_blocks"]).to eq [{ "html" => "<p>Intro</p>" }, { "html" => "<p>Body</p>" }]
    end
  end

  context "with blocks a previous submit already rendered" do
    let(:blocks) { [{ "html" => "<p>Intro</p>" }] }

    it "records nothing" do
      resolve

      expect(projekt.reload.imported_content_block_template_ids).to eq []
    end
  end
end
