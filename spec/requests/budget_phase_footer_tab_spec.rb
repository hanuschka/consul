require "rails_helper"

describe "Budget phase without a budget on the projekt page", type: :request do
  let(:projekt_phase) { create(:budget_phase, active: true) }
  let(:page) { projekt_phase.projekt.page }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    projekt_phase.reload.budget.destroy!
  end

  it "loads the phase tab" do
    get projekt_phase_footer_tab_page_path(page, projekt_phase), xhr: true

    expect(response).to have_http_status(:ok)
  end

  it "opens the page with the phase selected" do
    get page_path(page.slug, projekt_phase_id: projekt_phase.id)

    expect(response).to have_http_status(:ok)
  end
end
