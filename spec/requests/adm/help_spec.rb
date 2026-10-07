require "rails_helper"

describe "Help entry in /adm dashboards", type: :request do
  let(:manual) { "https://handbuch.example.org" }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    set_setting("handbook.url", manual)
  end

  def last_menu_link
    Nokogiri::HTML(response.body).css("#adm-sidebar nav.adm-menu > ul.nav-item-list > li > a").last
  end

  def iframe_src
    Nokogiri::HTML(response.body).at_css("iframe.adm-embed__iframe")["src"]
  end

  it "is preset to the demokratie.today manual" do
    expect(Setting.defaults.with_indifferent_access["handbook.url"]).to eq "https://handbuch.demokratie.today"
  end

  context "as an administrator" do
    before { login_as(create(:administrator).user) }

    {
      "administration"     => [:adm_root_path,                    "administration"],
      "projekts"           => [:adm_projekts_root_path,           "projekte"],
      "landing_pages"      => [:adm_landing_pages_root_path,      "themenseiten"],
      "moderation"         => [:adm_moderation_root_path,         "moderation"],
      "deficiency_reports" => [:adm_deficiency_reports_root_path, "maengelmelder"],
      "municipal_plans"    => [:adm_municipal_plans_root_path,    "vorhabenliste"],
      "ideas"              => [:adm_ideas_root_path,              "ideen"],
      "valuation"          => [:adm_valuation_root_path,          "budget-begutachtung"],
      "officing"           => [:adm_officing_root_path,           "abstimmungshelfer"]
    }.each do |section, (root, slug)|
      help_section = section == "administration" ? nil : section

      it "ends the #{section} menu with the help entry and opens the #{slug} section" do
        get public_send(root)

        expect(last_menu_link.text).to include I18n.t("adm.menu.items.help")
        expect(last_menu_link["href"]).to eq adm_help_path(adm_section: help_section)

        get adm_help_path(adm_section: help_section)

        expect(response).to have_http_status(:ok)
        expect(iframe_src).to eq "#{manual}/#{slug}/"
      end
    end

    it "opens a specific manual page including its position" do
      get adm_help_path(adm_section: "projekts", page: "projekte/neues-projekt/#anlegen")

      expect(iframe_src).to eq "#{manual}/projekte/neues-projekt/#anlegen"
    end

    it "falls back to the section for a page outside the configured manual" do
      get adm_help_path(adm_section: "projekts", page: "https://evil.example/x")
      expect(iframe_src).to eq "#{manual}/projekte/"

      get adm_help_path(adm_section: "projekts", page: "//evil.example/x")
      expect(iframe_src).to eq "#{manual}/projekte/"
    end

    it "hides the entry and the page when the address is empty" do
      set_setting("handbook.url", "")

      get adm_root_path
      expect(response.body).not_to include adm_help_path

      get adm_help_path
      expect(response).to have_http_status(:not_found)
    end
  end

  context "as a moderator" do
    before { login_as(create(:moderator).user) }

    it "sees the help entry in the moderation dashboard" do
      get adm_moderation_root_path

      expect(last_menu_link["href"]).to eq adm_help_path(adm_section: "moderation")

      get adm_help_path(adm_section: "moderation")
      expect(response).to have_http_status(:ok)
    end

    it "cannot open the help of a dashboard they do not see" do
      get adm_help_path(adm_section: "projekts")
      expect(response).to redirect_to(root_path)

      get adm_help_path
      expect(response).to redirect_to(root_path)
    end
  end
end
