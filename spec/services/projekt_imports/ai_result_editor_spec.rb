require "rails_helper"

describe ProjektImports::AiResultEditor do
  let(:projekt_import) do
    create(
      :projekt_import,
      status: "chatting",
      ai_result: { "content_blocks" => [{ "template_id" => 1, "content_data" => "Intro" }] }
    )
  end
  let(:journal) { double(:journal, propose: { "proposal_id" => "p1", "details" => { "count" => 1 } }) }
  let(:editor) { ProjektImports::AiResultEditor.new(projekt_import: projekt_import, journal: journal) }
  let(:catalogue) do
    [
      {
        "category" => { "id" => 1 },
        "templates" => [
          { "id" => 1, "name" => "text-heading", "description" => "Heading", "content" => "<p>a</p>", "hidden" => false },
          { "id" => 2, "name" => "slider-hidden", "description" => "Slider", "content" => "<p>b</p>", "hidden" => true }
        ]
      }
    ]
  end

  before do
    allow(ContentBlockTemplates::Catalogue).to receive(:call).with(section: "general").and_return(catalogue)
  end

  describe "#available_content_block_templates" do
    it "lists the visible templates only" do
      expect(editor.available_content_block_templates).to eq(
        [{ "id" => 1, "name" => "text-heading", "description" => "Heading" }]
      )
    end
  end

  describe "#propose_content_blocks" do
    it "proposes blocks built from available templates" do
      editor.propose_content_blocks([{ "template_id" => 1, "content_data" => "Neu" }])

      expect(journal).to have_received(:propose).with("replace_content_blocks", count: 1, blocks: anything)
    end

    it "rejects a hidden or unknown template id and names it" do
      blocks = [{ "template_id" => 2, "content_data" => "Slider" }, { "template_id" => 99, "content_data" => "?" }]

      expect { editor.propose_content_blocks(blocks) }
        .to raise_error(ProjektImports::AiResultEditor::UnavailableTemplatesError, /template ids 2, 99/)
      expect(journal).not_to have_received(:propose)
    end

    context "when the catalogue cannot be read" do
      let(:catalogue) { [] }

      it "rejects nothing" do
        editor.propose_content_blocks([{ "template_id" => 99, "content_data" => "?" }])

        expect(journal).to have_received(:propose)
      end
    end
  end
end
