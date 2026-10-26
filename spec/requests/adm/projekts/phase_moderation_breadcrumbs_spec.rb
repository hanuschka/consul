require "rails_helper"

describe "Adm phase moderation breadcrumbs", type: :request do
  let(:projekt_phase) { create(:projekt_phase, :proposal_phase) }
  let(:projekt) { projekt_phase.projekt }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
  end

  def sign_in_with(permission)
    manager = create(:projekt_manager)
    create(:projekt_manager_assignment, permission, projekt: projekt, projekt_manager: manager)
    login_as(manager.user)
  end

  def projekt_crumb
    Capybara.string(response.body).first(".breadcrumb-item:not(.breadcrumb-item--back)")
  end

  it "shows the projekt as plain text to a moderator who cannot open the phases page" do
    sign_in_with(:moderate)

    get proposals_adm_projekts_phase_path(projekt_phase)

    expect(response).to have_http_status(:ok)
    expect(projekt_crumb).to have_text(projekt.page.title)
    expect(projekt_crumb).not_to have_link
  end

  it "links the projekt to its phases page for a manager" do
    sign_in_with(:manage)

    get proposals_adm_projekts_phase_path(projekt_phase)

    expect(projekt_crumb).to have_link(projekt.page.title, href: phases_adm_projekts_projekt_path(projekt))
  end
end
