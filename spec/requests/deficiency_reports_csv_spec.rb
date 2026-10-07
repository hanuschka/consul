require "rails_helper"

describe "Mängelmelder CSV export", type: :request do
  before do
    set_setting("process.deficiency_reports", true)
    create(:deficiency_report, title: "Broken bench in the park", admin_accepted: true)
  end

  def export
    get deficiency_reports_path(format: :csv)
  end

  it "gives a signed-out visitor no CSV" do
    export

    expect(response).to redirect_to(deficiency_reports_path)
    expect(response.body).not_to include("Broken bench in the park")
  end

  it "gives a regular citizen no CSV" do
    login_as(create(:user))

    export

    expect(response).to redirect_to(deficiency_reports_path)
    expect(response.body).not_to include("Broken bench in the park")
  end

  it "gives a Mängelmelder officer with manage all no CSV either" do
    login_as(create(:deficiency_report_officer, manage_all: true).user)

    export

    expect(response).to redirect_to(deficiency_reports_path)
  end

  it "still lets an administrator download it" do
    login_as(create(:administrator).user)

    export

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq "text/csv"
    expect(response.body).to include("Broken bench in the park")
  end
end
