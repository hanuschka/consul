require "rails_helper"

describe SupportedLocales do
  let(:machine_only_locale) { :fr }

  describe ".served?" do
    it "serves the locales that ship translation files" do
      allow(MachineTranslation).to receive(:enabled?).and_return(false)

      expect(SupportedLocales.served?(:de)).to be true
      expect(SupportedLocales.served?(:en)).to be true
    end

    it "hides a machine-only locale while machine translation is off" do
      allow(MachineTranslation).to receive(:enabled?).and_return(false)

      expect(SupportedLocales.served?(machine_only_locale)).to be false
    end

    it "serves a machine-only locale once machine translation is on" do
      allow(MachineTranslation).to receive(:enabled?).and_return(true)

      expect(SupportedLocales.served?(machine_only_locale)).to be true
    end
  end

  describe ".adm?" do
    it "accepts only the locales the backoffice offers" do
      expect(SupportedLocales.adm?(:de)).to be true
      expect(SupportedLocales.adm?(machine_only_locale)).to be false
      expect(SupportedLocales.adm?(nil)).to be false
    end
  end
end
