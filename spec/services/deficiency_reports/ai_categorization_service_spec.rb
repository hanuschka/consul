require "rails_helper"

describe DeficiencyReports::AiCategorizationService do
  # chat_with_json_output(schema).with_instructions(prompt).ask(prompt, with: image) -> response
  def stub_llm_content(content)
    chat = double("chat")
    allow(chat).to receive(:ask).and_return(double("response", content: content))
    allow(Ai::RubyLlmFactory).to receive(:chat_with_json_output)
      .and_return(double("chat_builder", with_instructions: chat))
    chat
  end

  def stub_llm_failure(error)
    allow(Ai::RubyLlmFactory).to receive(:chat_with_json_output).and_raise(error)
  end

  let(:report) { create(:deficiency_report, title: "Schlagloch in der Hauptstraße") }
  let!(:fallback_category) { create(:deficiency_report_category, given_order: 1, ai_fallback: true) }
  let!(:category) { create(:deficiency_report_category, given_order: 2) }
  let!(:subcategory) { create(:deficiency_report_subcategory, category: category) }

  before do
    # Prompts are maintained centrally; the built-in prompt is what runs when the DT API is not
    # reachable, which is the only sensible thing to exercise in a test.
    allow(DtApi::Client).to receive(:new).and_raise(StandardError, "no DT API in test")
    allow(Ai::Settings).to receive(:ai_available?).and_return(true)
    set_setting("deficiency_reports.ai_categorization", true)
  end

  describe ".enabled?" do
    it "is false while the setting is off" do
      set_setting("deficiency_reports.ai_categorization", false)

      expect(DeficiencyReports::AiCategorizationService.enabled?).to be(false)
    end

    it "is false when no AI provider is configured" do
      allow(Ai::Settings).to receive(:ai_available?).and_return(false)

      expect(DeficiencyReports::AiCategorizationService.enabled?).to be(false)
    end

    it "is true with the setting on and a provider configured" do
      expect(DeficiencyReports::AiCategorizationService.enabled?).to be(true)
    end
  end

  describe "a confident classification" do
    it "returns the category and subcategory the model picked" do
      stub_llm_content("category_id" => category.id, "subcategory_id" => subcategory.id,
                       "confidence" => 0.9)

      result = DeficiencyReports::AiCategorizationService.new(report).call

      expect(result.category).to eq(category)
      expect(result.subcategory).to eq(subcategory)
      expect(result.confidence).to eq(0.9)
      expect(result.fallback?).to be(false)
      expect(result.fallback_reason).to be_nil
    end

    it "accepts a category without a subcategory" do
      stub_llm_content("category_id" => fallback_category.id, "subcategory_id" => nil,
                       "confidence" => 0.8)

      result = DeficiencyReports::AiCategorizationService.new(report).call

      expect(result.category).to eq(fallback_category)
      expect(result.subcategory).to be_nil
      expect(result.fallback?).to be(false)
    end

    # The model is told to send null when the category has no subcategories, but it is free to get
    # that wrong, so the pair is verified rather than trusted.
    it "drops a subcategory that does not belong to the chosen category" do
      foreign = create(:deficiency_report_subcategory, category: create(:deficiency_report_category))
      stub_llm_content("category_id" => category.id, "subcategory_id" => foreign.id,
                       "confidence" => 0.9)

      result = DeficiencyReports::AiCategorizationService.new(report).call

      expect(result.category).to eq(category)
      expect(result.subcategory).to be_nil
    end
  end

  describe "fallbacks" do
    it "falls back when the feature is off" do
      set_setting("deficiency_reports.ai_categorization", false)

      result = DeficiencyReports::AiCategorizationService.new(report).call

      expect(result.fallback_reason).to eq(:disabled)
      expect(result.category).to eq(fallback_category)
      expect(result.subcategory).to be_nil
      expect(result.fallback?).to be(true)
    end

    it "falls back when confidence is below the minimum" do
      stub_llm_content("category_id" => category.id, "subcategory_id" => nil, "confidence" => 0.4)

      result = DeficiencyReports::AiCategorizationService.new(report).call

      expect(result.fallback_reason).to eq(:low_confidence)
      expect(result.confidence).to eq(0.4)
      expect(result.category).to eq(fallback_category)
    end

    it "falls back when the model returns an id that is not in the taxonomy" do
      stub_llm_content("category_id" => 0, "subcategory_id" => nil, "confidence" => 0.95)

      result = DeficiencyReports::AiCategorizationService.new(report).call

      expect(result.fallback_reason).to eq(:unknown_category)
      expect(result.category).to eq(fallback_category)
    end

    it "falls back when the provider raises" do
      stub_llm_failure(StandardError.new("provider down"))

      result = DeficiencyReports::AiCategorizationService.new(report).call

      expect(result.fallback_reason).to eq(:service_error)
      expect(result.category).to eq(fallback_category)
    end

    it "falls back when the provider times out" do
      stub_llm_failure(Timeout::Error.new("too slow"))

      result = DeficiencyReports::AiCategorizationService.new(report).call

      expect(result.fallback_reason).to eq(:service_error)
    end

    it "falls back when no categories are configured" do
      DeficiencyReport::Subcategory.delete_all
      report
      DeficiencyReport.delete_all
      DeficiencyReport::Category.delete_all

      result = DeficiencyReports::AiCategorizationService.new(report).call

      expect(result.fallback_reason).to eq(:no_categories)
      expect(result.category).to be_nil
    end

    # A citizen's submission must never be lost to a classification problem.
    it "never raises" do
      stub_llm_content("nonsense" => true)

      expect { DeficiencyReports::AiCategorizationService.new(report).call }.not_to raise_error
    end
  end

  describe "the prompt" do
    it "lists every category with its subcategories and states when there are none" do
      chat = stub_llm_content("category_id" => category.id, "subcategory_id" => subcategory.id,
                              "confidence" => 0.9)

      DeficiencyReports::AiCategorizationService.new(report).call

      expect(chat).to have_received(:ask) do |prompt, _options|
        expect(prompt).to include(report.title)
        expect(prompt).to include("#{category.id}: #{category.name}")
        expect(prompt).to include("#{subcategory.id}: #{subcategory.name}")
        expect(prompt).to include("(keine Unterkategorien)")
      end
    end

    it "passes the administration's hint along with the category it belongs to" do
      category.update!(ai_hint: "Nur Straßenschäden, keine Gehwege")
      chat = stub_llm_content("category_id" => category.id, "subcategory_id" => nil,
                              "confidence" => 0.9)

      DeficiencyReports::AiCategorizationService.new(report).call

      expect(chat).to have_received(:ask) do |prompt, _options|
        expect(prompt).to include("Nur Straßenschäden, keine Gehwege")
        expect(prompt).to include("Abgrenzungshinweis")
      end
    end

    it "leaves the hint legend out when no hint is filled in" do
      chat = stub_llm_content("category_id" => category.id, "subcategory_id" => nil,
                              "confidence" => 0.9)

      DeficiencyReports::AiCategorizationService.new(report).call

      expect(chat).to have_received(:ask) do |prompt, _options|
        expect(prompt).not_to include("Abgrenzungshinweis")
      end
    end

    it "sends no attachment for a report without an image" do
      chat = stub_llm_content("category_id" => category.id, "subcategory_id" => nil,
                              "confidence" => 0.9)

      DeficiencyReports::AiCategorizationService.new(report).call

      expect(chat).to have_received(:ask).with(anything, with: nil)
    end
  end
end
