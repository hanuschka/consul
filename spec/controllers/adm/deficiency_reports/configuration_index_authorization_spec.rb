require "rails_helper"

# policy_scope does not gate an action — every Scope in this namespace resolves to `scope.all` — so
# each index has to authorize as well. Without that call the configuration screens are readable by
# any case worker, whatever the policy says. One example per screen, so removing an authorize call
# fails here rather than shipping quietly.
#
# Managers are covered by the per-controller specs; these examples only pin the refusal.
describe Adm::DeficiencyReports::CategoriesController do
  let(:officer) { create(:deficiency_report_officer) }

  before { sign_in officer.user }

  it "refuses an officer without manage_all" do
    get :index

    expect(response).to redirect_to(adm_deficiency_reports_root_path)
    expect(flash[:alert]).to be_present
  end

  it "admits an officer who manages all reports" do
    sign_in create(:deficiency_report_officer, manage_all: true).user

    get :index

    expect(response).to have_http_status(:ok)
  end
end

describe Adm::DeficiencyReports::StatusesController do
  before { sign_in create(:deficiency_report_officer).user }

  it "refuses an officer without manage_all" do
    get :index

    expect(response).to redirect_to(adm_deficiency_reports_root_path)
    expect(flash[:alert]).to be_present
  end
end

describe Adm::DeficiencyReports::OfficerGroupsController do
  before { sign_in create(:deficiency_report_officer).user }

  it "refuses an officer without manage_all" do
    get :index

    expect(response).to redirect_to(adm_deficiency_reports_root_path)
    expect(flash[:alert]).to be_present
  end
end

describe Adm::DeficiencyReports::DistrictsController do
  before { sign_in create(:deficiency_report_officer).user }

  it "refuses an officer without manage_all" do
    get :index

    expect(response).to redirect_to(adm_deficiency_reports_root_path)
    expect(flash[:alert]).to be_present
  end
end

# Answer templates are the case worker's own tool, so the policy admits officers here — the
# authorize call is what keeps that a deliberate decision rather than an accident.
describe Adm::DeficiencyReports::OfficialAnswerTemplatesController do
  it "admits an officer" do
    sign_in create(:deficiency_report_officer).user

    get :index

    expect(response).to have_http_status(:ok)
  end

  it "admits a manager" do
    sign_in create(:user).tap { |user| DeficiencyReportManager.create!(user: user) }

    get :index

    expect(response).to have_http_status(:ok)
  end
end
