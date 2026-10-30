require "rails_helper"

describe "Requesting a phase tab outside the page", type: :request do
  let(:projekt_phase) { create(:proposal_phase, active: true) }
  let(:path) { projekt_phase_footer_tab_page_path(projekt_phase.projekt.page, projekt_phase) }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
  end

  it "serves the tab to the page's own request" do
    get path, xhr: true

    expect(response).to have_http_status(:ok)
  end

  it "sends a request opened in a new browser tab to the page with the phase selected" do
    get path, params: { order: "most_voted" }

    expect(response).to redirect_to(
      page_path(projekt_phase.projekt.page.slug, projekt_phase_id: projekt_phase.id, order: "most_voted",
                                                 anchor: "projekt-footer")
    )

    follow_redirect!

    expect(response).to have_http_status(:ok)
  end

  it "rejects a request from a client that accepts any format" do
    get path, headers: { "Accept" => "*/*" }

    expect(response).to have_http_status(:not_acceptable)
    expect(response.body).to be_empty
  end
end
