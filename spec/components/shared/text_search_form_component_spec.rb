require "rails_helper"

describe Shared::TextSearchFormComponent, type: :component do
  def sign_in(user)
    allow(vc_test_controller).to receive(:current_user).and_return(user)
  end

  def render_form(query)
    with_request_url("/municipal_plans?#{query}") do
      namespace = "custom.municipal_plans.index.search_form"
      render_inline(Shared::TextSearchFormComponent.new(i18n_namespace: namespace))
    end
  end

  def hidden_values(name)
    page.all("input[type=hidden][name='#{name}']", visible: :all).map(&:value)
  end

  it "keeps every value of an array parameter" do
    render_form("districts[]=3&districts[]=5")

    expect(hidden_values("districts[]")).to eq %w[3 5]
    expect(page).not_to have_css("input[name='districts']", visible: :all)
  end

  it "keeps a single-value parameter as it was" do
    render_form("order=title")

    expect(hidden_values("order")).to eq ["title"]
  end

  it "leaves out the search term, the page and utf8" do
    render_form("search=Markt&page=2&utf8=%E2%9C%93&order=title")

    expect(hidden_values("search")).to be_empty
    expect(hidden_values("page")).to be_empty
    expect(hidden_values("utf8")).to be_empty
  end
end
