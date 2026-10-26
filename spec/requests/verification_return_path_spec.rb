require "rails_helper"

describe "Returning to the referring page after verification", type: :request do
  let(:user) { create(:user) }

  before do
    login_as(user)
    allow_any_instance_of(Verification::Residence).to receive(:save).and_return(true)
    allow(NotificationServices::NewManualVerificationRequestNotifier).to receive(:call)
  end

  it "redirects to the page the verification link was clicked on" do
    get verification_path, headers: { "HTTP_REFERER" => "http://www.example.com/projekts/budget?projekt_phase_id=7" }

    expect(response).to redirect_to(new_residence_path)

    post residence_path, params: { residence: { first_name: "Ada" }}

    expect(response).to redirect_to("/projekts/budget?projekt_phase_id=7#projekt-footer")
    expect(flash[:notice]).to eq I18n.t("custom.verification.residence.create.flash.success_manual")
  end

  it "ignores referers from other hosts" do
    get verification_path, headers: { "HTTP_REFERER" => "https://elsewhere.example/projekts/budget" }
    post residence_path, params: { residence: { first_name: "Ada" }}

    expect(response).to redirect_to(account_path)
  end

  it "falls back to the account page without a referer" do
    get verification_path
    post residence_path, params: { residence: { first_name: "Ada" }}

    expect(response).to redirect_to(account_path)
  end

  it "returns to the referer only once" do
    get verification_path, headers: { "HTTP_REFERER" => "http://www.example.com/projekts/budget" }
    post residence_path, params: { residence: { first_name: "Ada" }}

    expect(response.location).to eq("http://www.example.com/projekts/budget")

    post residence_path, params: { residence: { first_name: "Ada" }}

    expect(response).to redirect_to(account_path)
  end
end
