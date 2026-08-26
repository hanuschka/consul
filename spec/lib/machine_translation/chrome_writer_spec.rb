require "rails_helper"

describe MachineTranslation::ChromeWriter do
  let(:locale) { MachineTranslation.translatable_locales.first }
  let(:writer) { described_class.new(locale) }

  describe "placeholder integrity" do
    def intact?(source, output)
      writer.send(:placeholders_intact?, source, output)
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

  describe "wrapping" do
    it "wraps placeholders in ignore tags and unwraps them again" do
      wrapped = writer.send(:wrap, "Es wurden %{count} gefunden")

      expect(wrapped).to eq("Es wurden <x>%{count}</x> gefunden")
      expect(writer.send(:unwrap, wrapped)).to eq("Es wurden %{count} gefunden")
    end
  end

  describe "#store" do
    it "writes a row and never overwrites an existing translation" do
      writer.send(:store, "custom.spec_writer_probe", "erste")
      writer.send(:store, "custom.spec_writer_probe", "zweite")

      content = I18nContent.find_by(key: "custom.spec_writer_probe")
      expect(Globalize.with_locale(locale) { content.value }).to eq("erste")
      expect(I18nContent.where(key: "custom.spec_writer_probe").count).to eq(1)
    end
  end

  describe "#pending_entries" do
    it "skips keys the target locale already has stored" do
      key = writer.pending_entries.first[:key]
      writer.send(:store, key, "schon da")
      MachineTranslation::ChromeStore.reset!

      expect(described_class.new(locale).pending_entries.map { |e| e[:key] }).not_to include(key)
    end

    it "excludes denylisted namespaces" do
      keys = writer.pending_entries.map { |entry| entry[:key] }

      expect(keys.grep(/\A(adm|date|time|number)\./)).to be_empty
    end
  end
end
