require "rails_helper"

describe "Vorhabenliste home in /adm", type: :request do
  let(:admin) { create(:administrator).user }
  let(:officer) { create(:municipal_plan_officer) }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    Setting["municipal_plans.officers_see_all"] = false
  end

  it "shows the welcome page with the Vorhaben table loaded from the list" do
    login_as(admin)

    get adm_municipal_plans_root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("adm.municipal_plans.home.title"))
    expect(response.body).to include(adm_municipal_plans_municipal_plans_list_path)
  end

  it "shows the notice once it is switched on" do
    Setting["adm.municipal_plans.notice_message"] = "Redaktionsschluss am Freitag"
    Setting["adm.municipal_plans.notice_active"] = true
    login_as(admin)

    get adm_municipal_plans_root_path

    expect(response.body).to include("Redaktionsschluss am Freitag")
  end

  it "counts only the Vorhaben an officer may see" do
    create(:municipal_plan, responsible: officer)
    create(:municipal_plan)
    login_as(officer.user)

    get adm_municipal_plans_root_path

    expect(response).to have_http_status(:ok)
    expect(controller.instance_variable_get(:@stats).first[:value]).to eq(1)
  end

  it "keeps the Vorhaben table on the list page" do
    plan = create(:municipal_plan)
    login_as(admin)

    get adm_municipal_plans_municipal_plans_list_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(adm_municipal_plans_municipal_plan_path(plan))
  end

  it "turns away users without access" do
    login_as(create(:user))

    get adm_municipal_plans_root_path

    expect(response).to redirect_to(adm_root_path)
  end
end
