require "rails_helper"

describe "Admin information texts", type: :request do
  let(:admin) { create(:administrator).user }
  let(:machine_locale) { MachineTranslation.translatable_locales.first }
  let(:content) { I18nContent.create!(key: "debates.new.info") }

  before do
    login_as(admin)
    Globalize.with_locale(machine_locale) { content.update!(value: "Text") }
  end

  def disable_locale(locale)
    post admin_site_customization_information_texts_path,
         params: {
           contents: { "0" => { id: content.key, values: { "value_#{locale}" => "Text" }}},
           enabled_translations: { locale => "0" }
         }
  end

  def stored_translations
    I18nContentTranslation.where(i18n_content_id: content.id, locale: machine_locale.to_s)
  end

  it "keeps the translations of a locale machine translation writes" do
    allow(MachineTranslation).to receive(:enabled?).and_return(true)

    disable_locale(machine_locale)

    expect(stored_translations).to be_present
    expect(flash[:alert]).to be_present
    expect(flash[:alert]).not_to include("translation missing")
  end

  it "deletes the translations of a locale while machine translation is off" do
    allow(MachineTranslation).to receive(:enabled?).and_return(false)

    disable_locale(machine_locale)

    expect(stored_translations).to be_empty
    expect(flash[:alert]).to be_blank
  end
end
