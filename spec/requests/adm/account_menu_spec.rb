require "rails_helper"

describe "Dashboard links in the /adm account menu", type: :request do
  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
  end

  def flyout_links
    Nokogiri::HTML(response.body).css(".subnavigation-konto__flyout a").map { |link| link["href"] }
  end

  it "offers the municipal plans dashboard to an administrator" do
    login_as(create(:administrator).user)

    get adm_root_path

    expect(flyout_links).to include adm_municipal_plans_root_path
  end

  it "offers the municipal plans dashboard to a municipal plan officer" do
    login_as(create(:municipal_plan_officer).user)

    get adm_municipal_plans_root_path

    expect(flyout_links).to include adm_municipal_plans_root_path
  end

  it "does not offer the municipal plans dashboard to a moderator" do
    login_as(create(:moderator).user)

    get adm_moderation_root_path

    expect(flyout_links).not_to include adm_municipal_plans_root_path
  end
end
