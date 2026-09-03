require "rails_helper"

describe MachineTranslation::SettingText do
  let(:key) { "extended_option.general.title" }
  let(:target) { (MachineTranslation.translatable_locales - [MachineTranslation.source_locale]).first }
  let(:client) { instance_double(Deepl::Client) }

  def write_setting(setting_key, value)
    Setting[setting_key] = value
    Current.settings = nil
  end

  before do
    write_setting(key, "Beteiligung der Stadt")
    write_setting(MachineTranslation::SETTING_KEY, true)
    allow(Deepl).to receive(:configured?).and_return(true)
    allow(Deepl::Client).to receive(:new).and_return(client)
    allow(client).to receive(:translate).and_return(["Participation de la ville"])
    MachineTranslation::ChromeStore.reset!
    described_class.reset!
  end

  after do
    MachineTranslation::ChromeStore.reset!
    described_class.reset!
  end

  describe "when it must not translate" do
    it "returns the raw value while machine translation is disabled" do
      write_setting(MachineTranslation::SETTING_KEY, nil)

      expect(I18n.with_locale(target) { described_class.call(key) }).to eq "Beteiligung der Stadt"
      expect(client).not_to have_received(:translate)
    end

    it "returns the raw value in the source locale" do
      result = I18n.with_locale(MachineTranslation.source_locale) { described_class.call(key) }

      expect(result).to eq "Beteiligung der Stadt"
      expect(client).not_to have_received(:translate)
    end

    it "returns the raw value for a key outside the allowlist" do
      write_setting("org_name", "Stadt Jena")

      result = I18n.with_locale(target) { described_class.call("org_name") }

      expect(result).to eq "Stadt Jena"
      expect(client).not_to have_received(:translate)
    end

    it "returns nil for a blank setting without calling DeepL" do
      write_setting(key, "")

      expect(I18n.with_locale(target) { described_class.call(key) }).to be_blank
      expect(client).not_to have_received(:translate)
    end
  end

  describe "translating and storing" do
    it "translates on a miss and stores the result in I18nContent" do
      result = I18n.with_locale(target) { described_class.call(key) }

      expect(result).to eq "Participation de la ville"

      content = I18nContent.find_by(key: described_class.content_key_for(key, "Beteiligung der Stadt"))
      expect(content).to be_present
      expect(content.translations.find_by(locale: target.to_s).value).to eq "Participation de la ville"
    end

    it "reads the stored row on the next call instead of calling DeepL again" do
      I18n.with_locale(target) { described_class.call(key) }
      MachineTranslation::ChromeStore.reset!

      result = I18n.with_locale(target) { described_class.call(key) }

      expect(result).to eq "Participation de la ville"
      expect(client).to have_received(:translate).once
    end

    it "re-translates when the German value changes" do
      I18n.with_locale(target) { described_class.call(key) }

      write_setting(key, "Ein anderer Titel")
      allow(client).to receive(:translate).and_return(["Un autre titre"])
      MachineTranslation::ChromeStore.reset!

      expect(I18n.with_locale(target) { described_class.call(key) }).to eq "Un autre titre"
    end
  end

  describe "failure handling" do
    it "returns the German value when DeepL raises" do
      allow(client).to receive(:translate).and_raise(Deepl::ConnectionError, "boom")

      expect(I18n.with_locale(target) { described_class.call(key) }).to eq "Beteiligung der Stadt"
    end

    it "returns the German value when the translation drops a placeholder" do
      write_setting(key, "Beteiligung in %{city}")
      allow(client).to receive(:translate).and_return(["Participation dans la ville"])

      expect(I18n.with_locale(target) { described_class.call(key) }).to eq "Beteiligung in %{city}"
      expect(I18nContent.where("key LIKE ?", "#{described_class::NAMESPACE}.%")).to be_empty
    end

    it "retries with protected placeholders when the first attempt drops one" do
      write_setting(key, "Beteiligung in %{city}")
      sent = []
      allow(client).to receive(:translate) do |texts, **options|
        sent << [texts.first, options[:tag_handling]]
        sent.one? ? ["Participation dans la ville"] : ["Participation à <x>%{city}</x>"]
      end

      result = I18n.with_locale(target) { described_class.call(key) }

      expect(result).to eq "Participation à %{city}"
      expect(sent.first).to eq ["Beteiligung in %{city}", nil]
      expect(sent.last).to eq ["Beteiligung in <x>%{city}</x>", "xml"]
    end

    it "stops calling DeepL once a translation has failed" do
      allow(client).to receive(:translate).and_raise(Deepl::ConnectionError, "boom")

      2.times { I18n.with_locale(target) { described_class.call(key) } }

      expect(client).to have_received(:translate).once
    end

    it "translates again once the German value changes after a failure" do
      allow(client).to receive(:translate).and_raise(Deepl::ConnectionError, "boom")
      I18n.with_locale(target) { described_class.call(key) }

      write_setting(key, "Ein anderer Titel")
      allow(client).to receive(:translate).and_return(["Un autre titre"])

      expect(I18n.with_locale(target) { described_class.call(key) }).to eq "Un autre titre"
    end
  end

  describe ".stale_content_keys" do
    it "reports rows whose source value no longer matches" do
      I18n.with_locale(target) { described_class.call(key) }
      stored_key = described_class.content_key_for(key, "Beteiligung der Stadt")

      expect(described_class.stale_content_keys).not_to include stored_key

      write_setting(key, "Ein anderer Titel")

      expect(described_class.stale_content_keys).to include stored_key
    end
  end
end
