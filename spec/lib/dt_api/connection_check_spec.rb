require "rails_helper"

describe DtApi::ConnectionCheck do
  let(:dt_client) { instance_double(DtApi::Client, connection: connection) }
  let(:connection) { double("connection", status: response) }
  let(:response) do
    double("response", code: status_code, parsed_response: parsed_response)
  end
  let(:status_code) { 200 }
  let(:parsed_response) { { "authenticated" => true } }

  before do
    allow(DtApi::Client).to receive(:new).and_return(dt_client)
    allow(Dt).to receive(:connected?).and_return(true)
    allow(Dt).to receive(:domain).and_return("app.demokratie.today")
    allow(Dt).to receive(:url).and_return("https://app.demokratie.today")
    allow(InternalApiClient).to receive(:dt)
      .and_return(double("dt", domain: "app.demokratie.today"))
  end

  describe ".call" do
    context "when DT is connected, reachable and authenticated" do
      it "marks all three checks as passing" do
        result = described_class.call

        expect(result.dt_connected).to be(true)
        expect(result.api_accessible).to be(true)
        expect(result.connection_works).to be(true)
        expect(result.all_checks_passed?).to be(true)
      end

      it "exposes the DT domain from secrets and the registered client" do
        payload = described_class.call.as_json_payload

        expect(payload[:dt_domain]).to eq(
          secrets_domain: "app.demokratie.today",
          secrets_url: "https://app.demokratie.today",
          client_domain: "app.demokratie.today"
        )
      end

      it "builds a token-free JSON payload" do
        payload = described_class.call.as_json_payload

        expect(payload).to include(
          connected: true,
          api_accessible: true,
          authenticated: true,
          status_code: 200
        )
        expect(payload[:error]).to be_nil
      end
    end

    context "when DT responds 200 but not authenticated" do
      let(:parsed_response) { { "authenticated" => false } }

      it "is reachable but the connection does not work" do
        result = described_class.call

        expect(result.api_accessible).to be(true)
        expect(result.connection_works).to be(false)
        expect(result.all_checks_passed?).to be(false)
      end
    end

    context "when DT returns a server error" do
      let(:status_code) { 502 }
      let(:parsed_response) { nil }

      it "is not accessible and reports an error" do
        result = described_class.call

        expect(result.api_accessible).to be(false)
        expect(result.connection_works).to be(false)
        expect(result.api_accessible_error).to include("HTTP 502")
      end
    end

    context "when the DT request raises" do
      before do
        allow(connection).to receive(:status).and_raise(StandardError, "boom")
      end

      it "captures the error without raising" do
        result = described_class.call

        expect(result.connection_works).to be(false)
        expect(result.connection_error).to eq("boom")
      end
    end

    context "when DT is not connected" do
      before { allow(Dt).to receive(:connected?).and_return(false) }

      it "reports the missing-client error" do
        allow(InternalApiClient).to receive(:dt).and_return(nil)

        result = described_class.call

        expect(result.dt_connected).to be(false)
        expect(result.dt_connected_error).to be_present
      end
    end
  end
end
