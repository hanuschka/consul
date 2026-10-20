require "rails_helper"

describe Projekts::CreateContentBlockWithAiJob do
  let(:projekt) { create(:projekt) }

  def stub_llm_html(html)
    chat = double("chat")
    allow(chat).to receive(:ask)
      .and_return(RubyLLM::Message.new(role: :assistant, content: { "html" => html }.to_json))
    allow(Ai::RubyLlmFactory).to receive(:chat_with_json_output)
      .and_return(double("chat_builder", with_instructions: chat))
  end

  def generate(**options)
    ProjektContentBlocks::Services::DispatchCreateWithAi.call(
      projekt: projekt,
      prompt: "Ein Block über das Sommerfest",
      **options
    )
  end

  before do
    allow(DtApi::Client).to receive(:new).and_raise(StandardError, "no DT API in test")
  end

  it "saves the generated block on the projekt below the one it was added after" do
    existing = create(:site_customization_content_block, projekt: projekt)
    stub_llm_html("<p>Sommerfest am Marktplatz</p>")

    result = generate(previous_content_block_id: existing.id)

    content_block = projekt.content_blocks.find(result.content_block_id)
    expect(content_block.body).to eq("<p>Sommerfest am Marktplatz</p>")
    expect(content_block.ai_generation_data).to be_nil
    expect(content_block.position).to eq(existing.reload.position + 1)
  end

  it "keeps the previous content when replacing a block fails" do
    content_block = create(:site_customization_content_block, projekt: projekt, body: "<p>Alt</p>")
    allow(Ai::RubyLlmFactory).to receive(:chat_with_json_output).and_raise(StandardError, "boom")

    generate(mode: "replace", target_content_block_id: content_block.id)

    expect(content_block.reload.body).to eq("<p>Alt</p>")
    expect(content_block.ai_generation_status).to eq("failed")
  end
end
