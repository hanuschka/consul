require "rails_helper"

describe "Consent banner", type: :system do
  let(:banner) { ".klaro .cookie-notice:not(.cookie-notice-hidden)" }

  before { page.driver.browser.manage.delete_cookie("klaro") }

  def visit_home
    visit root_path(locale: :de)
  end

  def stored_consent
    JSON.parse(CGI.unescape(page.driver.browser.manage.cookie_named("klaro")[:value]))
  end

  context "with Google Übersetzer active" do
    before { set_setting("extended_feature.general.enable_google_translate", true) }

    it "offers Alle ablehnen next to Alle akzeptieren" do
      visit_home

      within(banner) do
        expect(page).to have_button("Alle ablehnen")
        expect(page).to have_button("Alle akzeptieren")
      end
    end

    it "keeps the translator off after Alle ablehnen and does not show the banner again" do
      visit_home
      within(banner) { click_button "Alle ablehnen" }

      visit_home

      expect(page).not_to have_css(banner)
      expect(stored_consent["google_translate_accepted"]).to be false
      expect(page).not_to have_css("#google_translate_element_desktop")
    end
  end

  context "without an optional service" do
    it "shows a notice with OK only and does not show it again after OK" do
      visit_home

      within(banner) do
        expect(page).to have_button("OK")
        expect(page).not_to have_button("Alle akzeptieren")
        expect(page).not_to have_button("Alle ablehnen")
        click_button "OK"
      end

      visit_home

      expect(page).not_to have_css(banner)
    end
  end

  it "links to the privacy policy and keeps the footer links reachable" do
    imprint = SiteCustomization::Page.find_by!(footer_key: "impressum")
    imprint.update!(status: "published")

    visit_home

    within(banner) { expect(page).to have_link("Datenschutzerklärung", href: "/privacy") }

    within(".subfooter-legal") { click_link imprint.title }

    expect(page).to have_current_path(page_path(imprint.slug))
  end
end
