require "rails_helper"

describe "Sign-in with SMS code", type: :request do
  let(:phone) { "+491711234567" }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    set_setting("extended_feature.general.sms_login", true)
    Sms::Adapters::Log.deliveries.clear
  end

  def sent_code
    Sms::Adapters::Log.deliveries.last[:text][/\b\d{6}\b/]
  end

  def request_code(number = "0171 1234567")
    post sms_sign_in_path, params: { phone: number }
  end

  def enter_code(code = sent_code)
    post sms_sign_in_code_path, params: { code: code }
  end

  def signed_in?
    get account_path
    response.status == 200
  end

  it "is not available while the setting is off" do
    set_setting("extended_feature.general.sms_login", false)

    expect { get new_sms_sign_in_path }.to raise_error(ActionController::RoutingError)
  end

  it "shows the number form" do
    get new_sms_sign_in_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("sms_sign_in.new.title"))
  end

  it "creates an account for a new number and signs it in" do
    request_code

    expect(response).to redirect_to(sms_sign_in_code_path)
    expect(Sms::Adapters::Log.deliveries.map { |delivery| delivery[:to] }).to eq [phone]

    expect { enter_code }.to change(User, :count).by(1)
    expect(User.last).to be_phone_account
    expect(User.last.confirmed_phone).to eq phone
    expect(signed_in?).to be true
  end

  it "signs in the existing account for a known number" do
    existing = create(:user, confirmed_phone: phone)

    request_code
    expect { enter_code }.not_to change(User, :count)

    get account_path
    expect(response).to have_http_status(:ok)
    expect(existing.reload.sign_in_count).to eq 1
  end

  it "answers the same for known and unknown numbers" do
    request_code("0171 1234567")
    unknown_response = [response.status, response.location]

    create(:user, confirmed_phone: "+4915112345678")
    request_code("0151 12345678")

    expect([response.status, response.location]).to eq unknown_response
  end

  it "returns to the intended path after passing through the code page" do
    get new_sms_sign_in_path, params: { intended_path: "/proposals" }
    request_code
    follow_redirect!
    enter_code

    expect(response).to redirect_to("/proposals")
  end

  it "returns to the last visited page after passing through the code page" do
    get "/proposals"
    get new_sms_sign_in_path
    request_code
    follow_redirect!
    enter_code

    expect(response).to redirect_to("/proposals")
  end

  it "rejects numbers that are not German mobile numbers without sending an SMS" do
    request_code("+34 612345678")

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include('aria-invalid="true"')
    expect(Sms::Adapters::Log.deliveries).to be_empty
  end

  it "does not mark the number field as invalid when the code request is only rate-limited" do
    request_code
    request_code

    expect(response).to have_http_status(:too_many_requests)
    expect(response.body).not_to include("aria-invalid")
  end

  it "shows the code form once a code was sent" do
    request_code
    get sms_sign_in_code_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("sms_sign_in.edit.title"))
    expect(response.body).not_to include("aria-invalid")
  end

  it "rejects a wrong code without signing in" do
    request_code
    enter_code(sent_code == "000000" ? "111111" : "000000")

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include(I18n.t("sms_sign_in.errors.invalid_code"))
    expect(response.body).to include('aria-invalid="true"')
    expect(signed_in?).to be false
  end

  it "rejects an expired code" do
    request_code
    code = sent_code

    travel_to((PhoneSignInCode::VALIDITY + 1.minute).from_now) do
      enter_code(code)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(I18n.t("sms_sign_in.errors.expired_code"))
    end
  end

  it "resends a new code after the waiting time" do
    request_code

    travel_to((PhoneSignInCode::RESEND_COOLDOWN + 1.second).from_now) do
      post resend_sms_sign_in_path

      expect(response).to redirect_to(sms_sign_in_code_path)
      expect(Sms::Adapters::Log.deliveries.size).to eq 2

      enter_code
      expect(signed_in?).to be true
    end
  end

  it "limits resending a code" do
    request_code
    post resend_sms_sign_in_path

    expect(response).to have_http_status(:too_many_requests)
    expect(Sms::Adapters::Log.deliveries.size).to eq 1
  end

  it "does not sign in a blocked account" do
    create(:user, confirmed_phone: phone).block

    request_code
    expect { enter_code }.not_to change(User, :count)

    expect(response).to redirect_to(new_sms_sign_in_path)
    expect(flash[:alert]).to eq I18n.t("sms_sign_in.errors.account_blocked")
    expect(signed_in?).to be false
  end

  it "sends the code page back to the number form without a number in the session" do
    get sms_sign_in_code_path

    expect(response).to redirect_to(new_sms_sign_in_path)
  end

  it "sends signed-in users away" do
    login_as(create(:user))

    get new_sms_sign_in_path

    expect(response).to redirect_to(root_path)
  end
end
