require "rails_helper"

describe MachineTranslation do
  describe ".placeholders_intact?" do
    def intact?(source, output)
      MachineTranslation.placeholders_intact?(source, output)
    end

    it "accepts an untouched placeholder" do
      expect(intact?("Es wurden %{count} Anliegen gefunden.", "%{count} requests found.")).to be true
    end

    it "rejects a dropped placeholder" do
      expect(intact?("Hallo %{name}", "Hello there")).to be false
    end

    it "rejects a renamed placeholder" do
      expect(intact?("Hallo %{name}", "Hello %{nombre}")).to be false
    end

    it "rejects text glued onto a placeholder" do
      expect(intact?("Es wurden %{count} Anliegen gefunden.", "%{count}s demandes ont ete trouvees.")).to be false
    end

    it "keeps a placeholder that was already glued in the source" do
      expect(intact?("%{count}x", "%{count}x")).to be true
    end

    it "does not mistake a percent sign before markup for a placeholder" do
      expect(intact?("36 Prozent im Jahr 1990", "36 %</a> en 1990")).to be true
    end

    it "accepts printf-style placeholders" do
      expect(intact?("Hallo %<name>s", "Hello %<name>s")).to be true
    end
  end
end
