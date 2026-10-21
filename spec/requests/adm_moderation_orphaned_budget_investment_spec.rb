require "rails_helper"

describe "Moderating a budget investment whose budget is gone", type: :request do
  let(:admin) { create(:administrator).user }
  let!(:investment) { create(:budget_investment, title: "Verwaister Vorschlag") }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    investment.update_column(:budget_id, Budget.maximum(:id) + 1)
    sign_in(admin)
  end

  def view_label
    I18n.t("adm.moderation.budget_investments.index.actions.view")
  end

  it "lists the investment without a link to its public page" do
    get adm_moderation_budget_investments_path(filter: "all")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Verwaister Vorschlag")
    expect(response.body).not_to include(view_label)
    expect(response.body).to include(hide_adm_moderation_budget_investment_path(investment))
  end

  it "still links an investment that has a budget" do
    create(:budget_investment, title: "Intakter Vorschlag")

    get adm_moderation_budget_investments_path(filter: "all")

    expect(response.body).to include("Intakter Vorschlag")
    expect(response.body).to include(view_label)
  end
end
