require "rails_helper"

describe Sms::Adapters::Esendex do
  let(:config) do
    {
      sender: "Musterstadt",
      esendex: { api_key: "secret-key", account_reference: "EXDE0000000" }
    }.with_indifferent_access
  end
  let(:adapter) { Sms::Adapters::Esendex.new(config) }

  def response(code, body)
    instance_double(HTTParty::Response, success?: code.between?(200, 299), code: code, parsed_response: body)
  end

  def deliver
    adapter.deliver(to: "+491711234567", text: "Ihr Bestätigungscode lautet: 123456")
  end

  it "sends one SMS with the configured sender and returns the message id" do
    sent = []
    allow(Sms::Adapters::Esendex).to receive(:post) do |url, **options|
      sent << [url, options]
      response(202, { "data" => { "requestId" => "r-1", "messageIds" => ["m-1"] } })
    end

    result = deliver

    expect(result).to be_success
    expect(result.message_id).to eq "m-1"
    expect(sent.size).to eq 1

    url, options = sent.first
    body = JSON.parse(options[:body])
    expect(url).to eq "https://api.esendex.de/v2/messages"
    expect(options[:headers]).to include("X-Api-Key" => "secret-key")
    expect(body).to include(
      "accountReference" => "EXDE0000000",
      "channel" => "SMS",
      "from" => "Musterstadt",
      "messageType" => "AuthenticationAndSecurity",
      "body" => { "text" => "Ihr Bestätigungscode lautet: 123456" },
      "recipients" => [{ "msisdn" => "+491711234567" }]
    )
    expect(Time.zone.parse(body["validity"])).to be_within(1.minute).of(15.minutes.from_now)
  end

  it "uses a configured base url" do
    config[:esendex][:base_url] = "https://api.dev.esendex.de"
    allow(Sms::Adapters::Esendex).to receive(:post).and_return(response(202, {}))

    deliver

    expect(Sms::Adapters::Esendex).to have_received(:post).with("https://api.dev.esendex.de/v2/messages", anything)
  end

  it "fails with the provider error codes when the request is rejected" do
    body = { "errors" => [{ "errorCode" => "unauthenticatedError", "errorMessage" => "unauthenticated" }] }
    allow(Sms::Adapters::Esendex).to receive(:post).and_return(response(401, body))

    result = deliver

    expect(result).not_to be_success
    expect(result.error).to eq "HTTP 401 unauthenticatedError"
  end

  it "fails on network errors" do
    allow(Sms::Adapters::Esendex).to receive(:post).and_raise(Net::ReadTimeout)

    result = deliver

    expect(result).not_to be_success
    expect(result.error).to eq "Net::ReadTimeout"
  end

  it "fails when the response body is not valid JSON" do
    allow(Sms::Adapters::Esendex).to receive(:post).and_raise(JSON::ParserError)

    result = deliver

    expect(result).not_to be_success
    expect(result.error).to eq "JSON::ParserError"
  end

  it "fails without a request when credentials are missing" do
    config[:esendex][:api_key] = ""
    allow(Sms::Adapters::Esendex).to receive(:post)

    expect(deliver).not_to be_success
    expect(Sms::Adapters::Esendex).not_to have_received(:post)
  end
end
