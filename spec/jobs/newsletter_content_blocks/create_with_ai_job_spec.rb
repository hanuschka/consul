require "rails_helper"

describe NewsletterContentBlocks::CreateWithAiJob do
  let(:newsletter) { create(:newsletter) }
  let(:technical_error) do
    'PG::UndefinedColumn: ERROR:  column "body" of relation "site_customization_content_blocks" ' \
      "does not exist"
  end

  def stub_llm_html(html)
    chat = double("chat")
    allow(chat).to receive(:ask)
      .and_return(RubyLLM::Message.new(role: :assistant, content: { "html" => html }.to_json))
    allow(Ai::RubyLlmFactory).to receive(:chat_with_json_output)
      .and_return(double("chat_builder", with_instructions: chat))
  end

  def stub_llm_failure(message)
    allow(Ai::RubyLlmFactory).to receive(:chat_with_json_output).and_raise(StandardError, message)
  end

  def generate(**options)
    NewsletterContentBlocks::DispatchCreateWithAi.call(
      newsletter: newsletter,
      prompt: "Ein Block über das Sommerfest",
      **options
    )
  end

  def status_payload(content_block_id)
    content_block = SiteCustomization::ContentBlock.unscoped.find(content_block_id)

    I18n.with_locale(:de) do
      SiteCustomization::ContentBlocks::AiGenerationStatusPayload.call(content_block: content_block)
    end
  end

  before do
    allow(DtApi::Client).to receive(:new).and_raise(StandardError, "no DT API in test")
  end

  describe "adding a block" do
    it "saves the generated content into the newsletter" do
      stub_llm_html("<p>Sommerfest am Marktplatz</p>")

      result = generate

      content_block = newsletter.content_blocks.find(result.content_block_id)
      expect(content_block.body).to eq("<p>Sommerfest am Marktplatz</p>")
      expect(content_block.ai_generation_data).to be_nil
      expect(content_block.key).to start_with("newsletter_content_block_#{newsletter.id}_")
      expect(status_payload(content_block.id)[:status]).to eq("completed")
    end

    it "inserts the block below the one it was added after" do
      first = create(:site_customization_content_block, newsletter: newsletter)
      last = create(:site_customization_content_block, newsletter: newsletter)
      stub_llm_html("<p>Neu</p>")

      result = generate(previous_content_block_id: first.id)

      expect(newsletter.content_blocks.reload.map(&:id)).to eq([first.id, result.content_block_id, last.id])
    end

    it "inserts the block at the top" do
      existing = create(:site_customization_content_block, newsletter: newsletter)
      stub_llm_html("<p>Neu</p>")

      result = generate(add_at_top: true)

      expect(newsletter.content_blocks.reload.map(&:id)).to eq([result.content_block_id, existing.id])
    end

    it "stores the content in the canonical locale and hands it to machine translation" do
      enqueued_bodies = []
      allow(MachineTranslation::Enqueuer).to receive(:new).and_wrap_original do |original, translation|
        enqueued_bodies << translation.body
        original.call(translation)
      end
      stub_llm_html("<p>Neu</p>")

      result = generate

      translation = SiteCustomization::ContentBlock.find(result.content_block_id)
                                                   .translations
                                                   .find_by!(locale: I18n.default_locale)
      expect(translation.body).to eq("<p>Neu</p>")
      expect(enqueued_bodies).to include("<p>Neu</p>")
    end

    it "leaves the newsletter unchanged when the generation fails" do
      existing = create(:site_customization_content_block, newsletter: newsletter)
      stub_llm_failure(technical_error)

      generate

      expect(newsletter.content_blocks.reload).to eq([existing])
    end
  end

  describe "replacing a block" do
    let!(:content_block) do
      create(:site_customization_content_block, newsletter: newsletter, body: "<p>Alt</p>")
    end

    it "replaces the content" do
      stub_llm_html("<p>Neu</p>")

      generate(mode: "replace", target_content_block_id: content_block.id)

      expect(content_block.reload.body).to eq("<p>Neu</p>")
      expect(content_block.ai_generation_data).to be_nil
    end

    it "keeps the previous content when the generation fails" do
      stub_llm_failure(technical_error)

      generate(mode: "replace", target_content_block_id: content_block.id)

      expect(newsletter.content_blocks.reload).to eq([content_block])
      expect(content_block.reload.body).to eq("<p>Alt</p>")
      expect(content_block.ai_generation_status).to eq("failed")
    end
  end

  describe "a failed generation" do
    it "reports a short German message instead of the technical error" do
      stub_llm_failure(technical_error)

      result = generate

      payload = status_payload(result.content_block_id)
      expect(payload[:status]).to eq("failed")
      expect(payload[:error]).to eq(message: "Fehler: Inhaltsblock konnte nicht mit KI generiert werden")
    end

    it "fails instead of staying in progress when the AI returns no content" do
      stub_llm_html("")

      result = generate

      payload = status_payload(result.content_block_id)
      expect(payload[:status]).to eq("failed")
      expect(payload[:error]).to eq(message: "Fehler: Inhaltsblock konnte nicht mit KI generiert werden")
    end
  end
end
