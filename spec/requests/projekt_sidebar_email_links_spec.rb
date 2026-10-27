require "rails_helper"

describe "E-mail links in the projekt information sidebar", type: :request do
  let(:projekt) { create(:projekt, name: "Westpark") }
  let(:block) do
    SiteCustomization::ContentBlock.create!(
      name: "custom",
      key: "projekt_sidebar_#{projekt.id}",
      locale: I18n.default_locale,
      projekt: projekt,
      body: "<p>Kontakt</p>"
    )
  end

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
  end

  def store_raw_body(body)
    block.translation.update_column(:body, body)
  end

  it "renders a stored bare e-mail address as a mailto link" do
    store_raw_body('<p><a href="info@example.org" target="_blank">info@example.org</a></p>')

    get page_path(projekt.page.slug)

    expect(response.body).to include('href="mailto:info@example.org"')
    expect(response.body).not_to include('href="info@example.org"')
  end

  it "renders a stored address resolved against the platform host as a mailto link" do
    store_raw_body('<p><a href="https://machmit.example.org/info@example.org%20">info@example.org</a></p>')

    get page_path(projekt.page.slug)

    expect(response.body).to include('href="mailto:info@example.org"')
    expect(response.body).not_to include('href="https://machmit.example.org/info@example.org')
  end

  it "keeps web links and platform page links unchanged" do
    store_raw_body('<p><a href="https://example.org/kontakt" target="_blank">web</a> <a href="/projekts">list</a></p>')

    get page_path(projekt.page.slug)

    expect(response.body).to include('href="https://example.org/kontakt"')
    expect(response.body).to include('href="/projekts"')
  end
end
