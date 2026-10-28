require "rails_helper"

describe "Adm budget phase without a budget", type: :request do
  let(:admin) { create(:administrator).user }
  let(:phase) { create(:budget_phase) }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    phase.reload.budget.destroy!
    login_as(admin)
  end

  it "shows an empty comment list" do
    get comments_adm_projekts_phase_path(phase)

    expect(response).to have_http_status(:ok)
  end

  it "redirects the budget settings to the phases page" do
    get budget_edit_adm_projekts_phase_path(phase)

    expect(response).to redirect_to(phases_adm_projekts_projekt_path(phase.projekt))
    expect(flash[:alert]).to eq I18n.t("adm.projekts.phases.missing_budget")
  end

  it "redirects the budget investments to the phases page" do
    get budget_investments_adm_projekts_phase_path(phase)

    expect(response).to redirect_to(phases_adm_projekts_projekt_path(phase.projekt))
    expect(flash[:alert]).to eq I18n.t("adm.projekts.phases.missing_budget")
  end
end
