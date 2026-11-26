require "rails_helper"

describe "API CORS" do
  include ApiClientHelper

  let(:allowed_origin) { "https://frontend.kki.iese.de" }
  let(:other_origin) { "https://evil.example.com" }
  let(:api_client) { create_api_client }

  before do
    allow(Rails.application.secrets).to receive(:cors_allowed_origins).and_return([allowed_origin])
  end

  def preflight(origin)
    process :options, "/api/budgets", headers: {
      "Origin" => origin,
      "Access-Control-Request-Method" => "POST",
      "Access-Control-Request-Headers" => "Authorization, Content-Type"
    }
  end

  describe "preflight" do
    it "allows a configured origin" do
      preflight(allowed_origin)

      expect(response).to have_http_status(:ok)
      expect(response.headers["Access-Control-Allow-Origin"]).to eq(allowed_origin)
      expect(response.headers["Access-Control-Allow-Methods"]).to include("POST")
    end

    it "does not need basic auth" do
      allow(Rails.application.secrets).to receive(:http_basic_auth).and_return(true)

      preflight(allowed_origin)

      expect(response).to have_http_status(:ok)
      expect(response.headers["Access-Control-Allow-Origin"]).to eq(allowed_origin)
    end

    it "gives another origin no allow-origin header" do
      preflight(other_origin)

      expect(response.headers["Access-Control-Allow-Origin"]).to be_nil
    end
  end

  describe "requests" do
    it "carries the headers for a configured origin" do
      get "/api/budgets", headers: {
        "Origin" => allowed_origin,
        "Authorization" => "Bearer #{api_client.access_token}"
      }

      expect(response).to have_http_status(:ok)
      expect(response.headers["Access-Control-Allow-Origin"]).to eq(allowed_origin)
      expect(response.headers["Access-Control-Allow-Credentials"]).to be_nil
      expect(response.headers["Vary"]).to include("Origin")
    end

    it "carries the headers on an error response" do
      get "/api/budgets", headers: { "Origin" => allowed_origin }

      expect(response).to have_http_status(:unauthorized)
      expect(response.headers["Access-Control-Allow-Origin"]).to eq(allowed_origin)
    end

    it "gives another origin no allow-origin header" do
      get "/api/budgets", headers: {
        "Origin" => other_origin,
        "Authorization" => "Bearer #{api_client.access_token}"
      }

      expect(response.headers["Access-Control-Allow-Origin"]).to be_nil
    end

    it "does not open non-API paths to a configured origin" do
      get "/", headers: { "Origin" => allowed_origin }

      expect(response.headers["Access-Control-Allow-Origin"]).to be_nil
    end
  end
end
