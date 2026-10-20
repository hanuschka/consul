require "rails_helper"

describe "Adm officing without an officing manager record", type: :request do
  let(:proposal_phase) { create(:proposal_phase) }
  let(:admin) { create(:administrator).user }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)

    login_as(admin)
  end

  it "answers Not Found on a phase's verify_user page" do
    expect do
      get verify_user_adm_officing_proposal_phase_path(proposal_phase)
    end.to raise_error(ActionController::RoutingError)
  end

  it "still shows the officing home page" do
    get adm_officing_root_path

    expect(response).to have_http_status(:ok)
  end
end
