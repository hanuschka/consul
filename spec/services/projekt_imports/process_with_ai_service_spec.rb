require "rails_helper"

describe ProjektImports::ProcessWithAiService do
  let(:text_html) { "<div><h3>Titel</h3><p>Text</p></div>" }
  let(:image_html) { %(<div><img src="https://placehold.co/600x400"><p>Text</p></div>) }

  let(:catalogue) do
    [
      {
        "category" => { "id" => 1 },
        "templates" => [
          { "id" => 11, "name" => "text-heading", "content" => text_html, "hidden" => false },
          { "id" => 12, "name" => "text-plain", "content" => text_html, "hidden" => false },
          { "id" => 13, "name" => "text-lead", "content" => text_html, "hidden" => false },
          { "id" => 14, "name" => "text-image", "content" => image_html, "hidden" => false },
          { "id" => 15, "name" => "text-quote", "content" => text_html, "hidden" => false }
        ]
      },
      {
        "category" => { "id" => 2 },
        "templates" => [
          { "id" => 21, "name" => "cards", "content" => text_html, "hidden" => false },
          { "id" => 22, "name" => "slider-hidden", "content" => image_html, "hidden" => true }
        ]
      }
    ]
  end

  let(:ai_request) { double(:ai_request, request_failed?: false, last_error: nil) }
  let(:ai_blocks) do
    [
      { "template_id" => 11, "content_data" => "Worum es geht" },
      { "template_id" => 21, "content_data" => "Mitmachen" }
    ]
  end
  let(:system_prompts) { [] }
  let(:schemas) { [] }

  before do
    allow(ContentBlockTemplates::Catalogue).to receive(:call).with(section: "general").and_return(catalogue)

    prompt_response = double(:prompt_response, parsed_response: { "consul_ai_prompt" => { "prompt" => "Base prompt" } })
    allow(DtApi::Client).to receive(:new).and_return(double(:dt_client, consul_ai_prompts: double(get: prompt_response)))
    allow(Ai::CorrectiveJsonRequest).to receive(:new) do |schema:, **|
      schemas << schema

      ai_request
    end

    allow(ai_request).to receive(:call) do |system_prompt:, **|
      system_prompts << system_prompt

      {
        "title" => "Spielplatz am See",
        "content_blocks" => ai_blocks.map(&:dup),
        "phases" => [],
        "clarification_questions" => ["Stimmt der Titel?", "Stimmen die Daten?"]
      }
    end
  end

  def process(recent_opening_template_ids)
    ProjektImports::ProcessWithAiService.call(
      text: "Ein neuer Spielplatz am See",
      response_language: "German",
      recent_opening_template_ids: recent_opening_template_ids
    )
  end

  def accepted_template_ids
    schemas.last.dig(:properties, :content_blocks, :items, :properties, :template_id, :enum)
  end

  it "offers every visible template on an instance without earlier imports" do
    result = process([])

    expect(result).to be_success
    expect(result.data[:ai_result]["content_blocks"]).to eq ai_blocks
    expect(accepted_template_ids).to eq [11, 12, 13, 14, 15, 21]
  end

  it "neither lists nor accepts the templates recent imports opened with" do
    process([11, 12])

    expect(system_prompts.last).not_to include("11 — text-heading")
    expect(system_prompts.last).not_to include("12 — text-plain")
    expect(system_prompts.last).to include("13 — text-lead")
    expect(accepted_template_ids).to eq [13, 14, 15, 21]
  end

  it "never offers a template that is hidden in the selector" do
    process([])

    expect(system_prompts.last).to include("21 — cards")
    expect(system_prompts.last).not_to include("22 — slider-hidden")
  end
end
