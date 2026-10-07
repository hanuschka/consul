require "rails_helper"

describe MachineTranslation::ChromeWriter do
  let(:locale) { MachineTranslation.translatable_locales.first }
  let(:writer) { described_class.new(locale) }

  describe "wrapping" do
    it "wraps placeholders in ignore tags and unwraps them again" do
      wrapped = MachineTranslation::TextMode.wrap("Es wurden %{count} gefunden")

      expect(wrapped).to eq("Es wurden <x>%{count}</x> gefunden")
      expect(MachineTranslation::TextMode.unwrap(wrapped)).to eq("Es wurden %{count} gefunden")
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
