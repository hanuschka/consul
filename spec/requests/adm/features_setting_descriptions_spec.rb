require "rails_helper"

# Guards the standard CON-3001 established for adm > Applikation > Funktionen: every setting the
# page shows explains itself in three sentences rather than restating its own label. Deliberately
# structural — pinning the wording would turn every copy tweak into a spec change.
describe "Setting descriptions on adm > Applikation > Funktionen" do
  minimum_sentences = 3
  minimum_length = 150
  maximum_length = 250

  def sentence_count(text)
    text.split(/(?<=[.!?])\s+/).count { |part| part.strip.length > 1 }
  end

  Adm::FeaturesController.const_get(:GENERAL_SETTING_KEYS)
    .+(Adm::FeaturesController.const_get(:GENERAL_TEXT_SETTING_KEYS))
    .+(Adm::FeaturesController.const_get(:OAUTH_LOGIN_SETTING_KEYS))
    .+(Adm::FeaturesController.const_get(:KOBIL_SETTING_KEYS))
    .each do |key|
      %i[de en].each do |locale|
        it "explains #{key} in #{locale}" do
          description = I18n.t("setting.#{key}_description", locale: locale, default: nil)

          expect(description).to be_present,
            "no #{locale} description for setting #{key}"

          visible = ActionController::Base.helpers.strip_tags(description)

          expect(visible.length).to be >= minimum_length,
            "#{locale} description for #{key} is #{visible.length} visible chars, " \
            "expected at least #{minimum_length}: #{visible}"
          expect(visible.length).to be <= maximum_length,
            "#{locale} description for #{key} is #{visible.length} visible chars, " \
            "expected at most #{maximum_length} so it stays about four lines: #{visible}"
          expect(sentence_count(description)).to be >= minimum_sentences,
            "#{locale} description for #{key} has #{sentence_count(description)} sentences, " \
            "expected at least #{minimum_sentences}: #{description}"
        end
      end
    end

  it "keeps the Google Translate terms-of-use link" do
    %i[de en].each do |locale|
      description = I18n.t("setting.extended_feature.general.enable_google_translate_description",
                           locale: locale)

      expect(description).to include("https://docs.google.com/forms/")
    end
  end

  it "keeps the server-credentials note on every external login service" do
    Adm::FeaturesController.const_get(:OAUTH_LOGIN_SETTING_KEYS)
      .+(["feature.kobil_login"])
      .each do |key|
        expect(I18n.t("setting.#{key}_description", locale: :de)).to include("Serverkonfiguration")
        expect(I18n.t("setting.#{key}_description", locale: :en)).to include("configured on the server")
      end
  end
end
