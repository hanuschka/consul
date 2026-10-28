require "rails_helper"

describe "Adm contribution access for projekt managers", type: :request do
  let(:projekt_phase) { create(:proposal_phase) }
  let(:projekt) { projekt_phase.projekt }
  let!(:poi_phase) { create(:point_of_interest_phase, projekt: projekt) }
  let!(:proposal) { create(:proposal, projekt_phase: projekt_phase, admin_accepted: false) }
  let(:toggle_path) { toggle_admin_accepted_adm_projekts_phase_proposal_path(projekt_phase, proposal) }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    projekt_phase.settings.find_by!(key: "feature.general.require_admin_acceptance").update!(value: "active")
  end

  def sign_in_with(*permissions)
    manager = create(:projekt_manager)
    create(:projekt_manager_assignment, *permissions, projekt: projekt, projekt_manager: manager)
    login_as(manager.user)
  end

  def page
    Capybara.string(response.body)
  end

  def toggle_admin_accepted(value)
    patch toggle_path, params: { proposal: { admin_accepted: value }}, as: :turbo_stream
  end

  shared_examples "a contributions-only projekt manager" do
    it "links the projekt title and the contributions action to the phase list" do
      get adm_projekts_projekts_list_path

      expect(page).to have_link(projekt.title, href: phases_adm_projekts_projekt_path(projekt))
      expect(page).to have_link(href: phases_adm_projekts_projekt_path(projekt), count: 2)
      expect(page).not_to have_link(href: details_adm_projekts_projekt_path(projekt))
    end

    it "lists only phases with contributions and no other projekt pages" do
      get phases_adm_projekts_projekt_path(projekt)

      expect(response).to have_http_status(:ok)
      expect(page).to have_link(href: proposals_adm_projekts_phase_path(projekt_phase))
      expect(page).not_to have_text(poi_phase.title)
      expect(page).not_to have_link(href: details_adm_projekts_projekt_path(projekt))
      expect(page).not_to have_link(href: images_adm_projekts_projekt_path(projekt))
      expect(page).not_to have_link(href: duration_adm_projekts_phase_path(projekt_phase))
    end

    it "links the phase breadcrumb back to the phase list" do
      get proposals_adm_projekts_phase_path(projekt_phase)

      expect(page).to have_link(projekt.page.title, href: phases_adm_projekts_projekt_path(projekt))
    end

    it "is refused the projekt settings" do
      get details_adm_projekts_projekt_path(projekt)

      expect(response).to redirect_to(root_path)
    end
  end

  context "with only 'approve'" do
    before { sign_in_with(:approve) }

    it_behaves_like "a contributions-only projekt manager"

    it "shows the approval switch and can switch the approval on and off" do
      get proposals_adm_projekts_phase_path(projekt_phase)
      expect(page).to have_css("[action='#{toggle_path}']")

      toggle_admin_accepted("1")
      expect(proposal.reload.admin_accepted).to be true

      toggle_admin_accepted("0")
      expect(proposal.reload.admin_accepted).to be false
    end
  end

  context "with only 'moderate'" do
    before { sign_in_with(:moderate) }

    it_behaves_like "a contributions-only projekt manager"

    it "shows no approval switch" do
      get proposals_adm_projekts_phase_path(projekt_phase)

      expect(response).to have_http_status(:ok)
      expect(page).not_to have_css("[action='#{toggle_path}']")
      expect(page).to have_link(href: hide_adm_projekts_phase_proposal_path(projekt_phase, proposal))
    end

    it "is refused an approval request" do
      toggle_admin_accepted("1")

      expect(proposal.reload.admin_accepted).to be false
    end
  end

  context "with 'manage'" do
    before { sign_in_with(:manage) }

    it "keeps the full actions menu and links the title to the projekt settings" do
      get adm_projekts_projekts_list_path

      expect(page).to have_link(projekt.title, href: details_adm_projekts_projekt_path(projekt))
      expect(page).to have_link(href: visibility_adm_projekts_projekt_path(projekt))
      expect(page).to have_link(href: phases_adm_projekts_projekt_path(projekt), count: 1)
    end

    it "lists every phase" do
      get phases_adm_projekts_projekt_path(projekt)

      expect(page).to have_text(poi_phase.title)
    end
  end
end
