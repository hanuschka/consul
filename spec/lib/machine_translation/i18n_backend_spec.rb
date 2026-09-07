require "rails_helper"

describe MachineTranslation::I18nBackend do
  let(:locale) { MachineTranslation.translatable_locales.first }
  let(:key) { "custom.spec_plural_probe" }

  def store(suffix, value)
    content = I18nContent.create!(key: [key, suffix].compact.join("."))
    Globalize.with_locale(locale) { content.update!(value: value) }
    MachineTranslation::ChromeStore.reset!
  end

  before { MachineTranslation::ChromeStore.reset! }
  after { MachineTranslation::ChromeStore.reset! }

  it "assembles a pluralized entry from one row per category" do
    store("one", "1 Kommentar")
    store("other", "%{count} Kommentare")

    expect(I18n.t(key, count: 1, locale: locale)).to eq("1 Kommentar")
    expect(I18n.t(key, count: 5, locale: locale)).to eq("5 Kommentare")
  end

  it "falls through when the category this count needs is missing" do
    store("one", "1 Kommentar")

    expect(I18n.t(key, count: 5, locale: locale, default: "fallback")).to eq("fallback")
  end

  it "still resolves plain keys" do
    store(nil, "Hallo")

    expect(I18n.t(key, locale: locale)).to eq("Hallo")
  end

  it "does not treat a plain stored string as pluralized" do
    store(nil, "Hallo")

    expect(I18n.t(key, count: 3, locale: locale)).to eq("Hallo")
  end
end
