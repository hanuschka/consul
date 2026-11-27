require "rails_helper"

describe "Adm officing proposal desk", type: :request do
  let(:proposal_phase) { create(:projekt_phase, :proposal_phase) }
  let(:officer) { create(:administrator).user }
  let(:offline_user) { create(:user) }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)

    allow_any_instance_of(ProjektPhase::ProposalPhase).to receive(:permission_problem).and_return(nil)

    officing_manager = OfficingManager.create!(user: officer)
    OfficingManagerAssignment.create!(officing_manager: officing_manager, projekt_phase: proposal_phase)

    login_as(officer)
  end

  it "lists every proposal on one page by its number" do
    proposals = create_list(:proposal, 12, projekt_phase: proposal_phase)

    get officing_desk_adm_officing_proposal_phase_path(proposal_phase, offline_user_id: offline_user.id)

    expect(response).to have_http_status(:ok)
    positions = proposals.map { |proposal| response.body.index(proposal.title) }
    expect(positions).to all(be_present)
    expect(positions).to eq positions.sort
  end
end
