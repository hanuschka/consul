require "rails_helper"

describe "Locale handling in /adm", type: :request do
  let(:admin) { create(:administrator).user }
  let(:adm_locale) { SupportedLocales::ADM.keys.first }
  let(:foreign_locale) { :fr }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    allow(MachineTranslation::Stats).to receive(:usage).and_return(
      "character_count" => 1_000, "character_limit" => 500_000
    )
    login_as(admin)
  end

  it "renders a locale the language selector offers" do
    get adm_machine_translations_path(locale: adm_locale)

    expect(response.body).to include(%(<html lang="#{adm_locale}">))
  end

  it "falls back to the default locale for a locale the selector cannot offer" do
    get adm_machine_translations_path(locale: foreign_locale)

    expect(response.body).to include(%(<html lang="#{I18n.default_locale}">))
    expect(response.body).not_to include(%(<html lang="#{foreign_locale}">))
  end

  it "keeps the user's front-end locale when the url carries a locale /adm cannot offer" do
    admin.update!(locale: foreign_locale.to_s)

    get adm_machine_translations_path(locale: foreign_locale)

    expect(response.body).to include(%(<html lang="#{I18n.default_locale}">))
    expect(admin.reload.locale).to eq foreign_locale.to_s
  end

  it "ignores a machine-translated locale carried over in the session" do
    get root_path(locale: foreign_locale)
    get adm_machine_translations_path

    expect(response.body).to include(%(<html lang="#{I18n.default_locale}">))
  end
end
