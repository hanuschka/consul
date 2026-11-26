require "rails_helper"

describe ProjektContentBlocks::AiGenerateWithPrompt do
  let(:projekt) { create(:projekt) }
  let(:chat) { double(:chat) }
  let(:instructions) { [] }

  before do
    allow(ContentBlockTemplates::Catalogue).to receive(:call).with(section: "projekt_page").and_return(
      [
        {
          "category" => { "id" => 1, "name_de" => "Basis" },
          "templates" => [
            { "id" => 11, "name" => "text-heading", "content" => "<p>a</p>", "hidden" => false },
            { "id" => 12, "name" => "slider-hidden", "content" => "<p>b</p>", "hidden" => true },
            { "id" => 13, "name" => "text-plain", "content" => "<p>c</p>", "hidden" => false }
          ]
        }
      ]
    )

    prompt_response = double(:prompt_response, success?: true)
    allow(prompt_response).to receive(:dig).with("consul_ai_prompt", "prompt").and_return("Base prompt")
    allow(DtApi::Client).to receive(:new).and_return(double(:dt_client, consul_ai_prompts: double(get: prompt_response)))

    allow(Ai::RubyLlmFactory).to receive(:chat_with_json_output).and_return(chat)
    allow(Ai::RubyLlmFactory).to receive(:attach_tools)
    allow(chat).to receive(:with_instructions) do |text|
      instructions << text
      chat
    end
    allow(chat).to receive(:ask).and_return(double(:response))
    allow(Ai::StructuredOutput).to receive(:content_of).and_return(nil)
  end

  it "never offers a template that is hidden in the selector" do
    ProjektContentBlocks::AiGenerateWithPrompt.call(projekt: projekt)

    expect(instructions.last).to include("name: text-heading, id: 11")
    expect(instructions.last).to include("name: text-plain, id: 13")
    expect(instructions.last).not_to include("slider-hidden")
  end
end
