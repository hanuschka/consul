require "rails_helper"

describe "Loading a phase tab by its number", type: :request do
  let(:projekt) { create(:projekt) }
  let(:projekt_phase) { create(:proposal_phase, projekt: projekt, active: true) }
  let(:citizen) { create(:user) }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
  end

  def load_tab
    get projekt_phase_footer_tab_page_path(projekt.page, projekt_phase, format: :js), xhr: true
  end

  def project_manager
    manager = create(:projekt_manager)
    create(:projekt_manager_assignment, projekt: projekt, projekt_manager: manager, permissions: ["manage"])
    manager.user
  end

  it "serves a visible phase of a public projekt to anyone" do
    load_tab

    expect(response).to have_http_status(:ok)
  end

  context "when the phase is hidden from the frontend" do
    before { projekt_phase.update!(frontend_visibility: false) }

    it "returns nothing to a signed-out visitor or a citizen" do
      load_tab
      expect(response).to have_http_status(:not_found)

      login_as(citizen)
      load_tab
      expect(response).to have_http_status(:not_found)
    end

    it "still serves it to an administrator and the projekt's manager" do
      login_as(create(:administrator).user)
      load_tab
      expect(response).to have_http_status(:ok)

      login_as(project_manager)
      load_tab
      expect(response).to have_http_status(:ok)
    end
  end

  context "when the projekt is a draft" do
    before { projekt.update!(activated: false) }

    it "returns nothing to a citizen" do
      login_as(citizen)
      load_tab

      expect(response).to have_http_status(:not_found)
    end
  end

  context "when the projekt is restricted to a group" do
    let(:value) { create(:individual_group_value, individual_group: create(:individual_group, kind: "hard")) }

    before { projekt.individual_group_values << value }

    it "returns nothing to a citizen outside the group" do
      login_as(citizen)
      load_tab

      expect(response).to have_http_status(:not_found)
    end

    it "serves it to a member of the group" do
      create(:user_individual_group_value, user: citizen, individual_group_value: value)
      login_as(citizen)
      load_tab

      expect(response).to have_http_status(:ok)
    end
  end
end
