require "rails_helper"

describe Admin::FeaturesService do
  before do
    allow(Ai::Settings).to receive(:ai_available?).and_return(true)
    allow(Ai::Settings).to receive(:current_llm_provider).and_return("openai")
    allow(Ai::Settings).to receive(:current_llm_model).and_return("gpt-5.4")
  end

  def set_endpoint(value)
    Setting["ai.llm_api_endpoint"] = value
    Current.settings = nil
  end

  describe "ai custom_endpoint" do
    it "reports absent when no endpoint is configured" do
      set_endpoint(nil)

      expect(described_class.call.dig(:ai, :custom_endpoint)).to eq(present: false, host: nil)
    end

    it "reports the host of a configured endpoint" do
      set_endpoint("https://api.example.com/v1")

      expect(described_class.call.dig(:ai, :custom_endpoint)).to eq(
        present: true,
        host: "api.example.com"
      )
    end

    it "extracts the host of a scheme-less endpoint" do
      set_endpoint("127.0.0.1:11434/v1")

      expect(described_class.call.dig(:ai, :custom_endpoint, :host)).to eq "127.0.0.1"
    end

    it "never exposes credentials or query parameters" do
      set_endpoint("https://user:secret@api.example.com/v1?token=abc")

      expect(described_class.call.dig(:ai, :custom_endpoint, :host)).to eq "api.example.com"
    end

    it "returns no host for an unparsable endpoint" do
      set_endpoint("not a url")

      expect(described_class.call.dig(:ai, :custom_endpoint)).to eq(present: true, host: nil)
    end
  end

  describe "ai projekt_import_tools" do
    it "reports every package installed" do
      allow(ExternalTool).to receive(:installed?).and_return(true)

      tools = described_class.call.dig(:ai, :projekt_import_tools)

      expect(tools[:all_installed]).to be true
      expect(tools[:missing_packages]).to be_empty
      expect(tools[:packages]["poppler-utils"][:commands]).to eq %w[pdftotext pdfimages]
    end

    it "groups both poppler commands under a single missing package" do
      allow(ExternalTool).to receive(:installed?).and_return(true)
      allow(ExternalTool).to receive(:installed?).with("pdftotext").and_return(false)
      allow(ExternalTool).to receive(:installed?).with("pdfimages").and_return(false)

      tools = described_class.call.dig(:ai, :projekt_import_tools)

      expect(tools[:all_installed]).to be false
      expect(tools[:missing_packages]).to eq ["poppler-utils"]
      expect(tools[:packages]["poppler-utils"][:missing_commands]).to eq %w[pdftotext pdfimages]
      expect(tools[:packages]["pandoc"][:installed]).to be true
    end

    it "treats a package as installed when any of its commands is present" do
      allow(ExternalTool).to receive(:installed?).and_return(false)
      allow(ExternalTool).to receive(:installed?).with("convert").and_return(true)

      tools = described_class.call.dig(:ai, :projekt_import_tools)

      expect(tools[:packages]["imagemagick"][:installed]).to be true
      expect(tools[:missing_packages]).to eq ["pandoc", "poppler-utils"]
    end
  end

  describe "existing keys" do
    it "keeps the keys the monitoring dashboard already reads" do
      expect(described_class.call[:ai].keys).to include(
        :enabled, :custom_client_token, :ai_model, :ai_provider
      )
    end
  end
end
