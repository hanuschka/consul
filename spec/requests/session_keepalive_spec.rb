require "rails_helper"

describe "Session keepalive", type: :request do
  let(:user) { create(:user) }
  let(:json_headers) { { "ACCEPT" => "application/json" } }

  def remaining_seconds
    get session_keepalive_status_path, headers: json_headers, xhr: true
    response.parsed_body["remaining_seconds"]
  end

  before { login_as(user) }

  it "reports the remaining time without extending the session" do
    freeze_time do
      post session_keepalive_ping_path, xhr: true

      travel 20.minutes
      expect(remaining_seconds).to eq 10.minutes.to_i

      travel 5.minutes
      expect(remaining_seconds).to eq 5.minutes.to_i
    end
  end

  it "reports an expired session without signing it out" do
    freeze_time do
      post session_keepalive_ping_path, xhr: true

      travel 31.minutes
      expect(remaining_seconds).to be <= 0

      post session_keepalive_ping_path, xhr: true
      expect(response).to have_http_status(:unauthorized)
    end
  end

  it "extends the session on ping" do
    freeze_time do
      post session_keepalive_ping_path, xhr: true

      travel 20.minutes
      post session_keepalive_ping_path, xhr: true

      expect(remaining_seconds).to eq 30.minutes.to_i
    end
  end

  it "answers 401 once the user is signed out" do
    logout

    get session_keepalive_status_path, headers: json_headers, xhr: true

    expect(response).to have_http_status(:unauthorized)
  end
end

describe "Requests with a stale authenticity token", type: :request do
  around do |example|
    ActionController::Base.allow_forgery_protection = true
    example.run
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  it "sends a signed-out visitor to the sign-in page" do
    post session_keepalive_ping_path, params: { authenticity_token: "stale" }

    expect(response).to redirect_to new_user_session_path
    expect(flash[:alert]).to eq I18n.t("devise.failure.timeout")
  end

  it "sends a signed-out remote form to the sign-in page" do
    post session_keepalive_ping_path, params: { authenticity_token: "stale" }, xhr: true

    expect(response.body).to include "Turbolinks.visit"
    expect(response.body).to include new_user_session_path
  end

  it "answers 401 to a signed-out JSON request" do
    post session_keepalive_ping_path, params: { authenticity_token: "stale" },
                                      headers: { "ACCEPT" => "application/json" }, xhr: true

    expect(response).to have_http_status(:unauthorized)
  end

  it "still rejects a stale token from a signed-in user" do
    login_as(create(:user))

    expect do
      post session_keepalive_ping_path, params: { authenticity_token: "stale" }
    end.to raise_error(ActionController::InvalidAuthenticityToken)
  end
end
