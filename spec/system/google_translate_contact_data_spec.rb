require "rails_helper"

describe "E-mail addresses under the Google Translate widget", type: :system do
  let(:address) { "verkehrsplanung.mtba@augsburg.de" }
  let(:protected_address) { "span.notranslate[translate='no']" }

  before do
    set_setting("extended_feature.general.enable_google_translate", true)
    SiteCustomization::ContentBlock
      .find_or_initialize_by(name: "custom", locale: SiteCustomization::ContentBlock.canonical_locale, key: "home_page_1")
      .update!(body: "<p>Kontakt: #{address}</p>" \
                     "<p><a href=\"mailto:info@augsburg.de\">info@augsburg.de</a></p>")
  end

  def accept_google_translate
    page.driver.browser.execute_cdp(
      "Page.addScriptToEvaluateOnNewDocument",
      source: "window.google = { translate: { TranslateElement: function() {} } };"
    )
    visit root_path
    page.driver.browser.manage.add_cookie(
      name: "klaro",
      value: CGI.escape({ system: true, google_translate_accepted: true }.to_json)
    )
    visit root_path
  end

  it "keeps the address in page content out of the translation" do
    accept_google_translate

    expect(page).to have_css(protected_address, exact_text: address)
  end

  it "keeps a mailto link's text and target out of the translation" do
    accept_google_translate

    expect(page).to have_css("a.notranslate[translate='no'][href='mailto:info@augsburg.de']",
                             exact_text: "info@augsburg.de")
  end

  it "marks addresses in content added after the page has loaded, but not inside editors" do
    accept_google_translate
    expect(page).to have_css(protected_address, exact_text: address)

    page.execute_script(<<~JS)
      var added = document.createElement("p");
      added.id = "added";
      added.textContent = "Neu: buergerbuero@augsburg.de";
      document.body.appendChild(added);

      var editor = document.createElement("div");
      editor.id = "editor";
      editor.setAttribute("contenteditable", "true");
      editor.textContent = "entwurf@augsburg.de";
      document.body.appendChild(editor);
    JS

    expect(page).to have_css("#added #{protected_address}", exact_text: "buergerbuero@augsburg.de")
    expect(page).to have_css("#editor", exact_text: "entwurf@augsburg.de")
    expect(page).not_to have_css("#editor span")
  end

  it "leaves the page untouched for editors, whose content blocks are edited in place" do
    login_as(create(:administrator).user)
    accept_google_translate

    expect(page).to have_content(address)
    expect(page.evaluate_script("typeof window.NoTranslateContactData")).to eq("undefined")
    expect(page).not_to have_css(protected_address)
  end
end
