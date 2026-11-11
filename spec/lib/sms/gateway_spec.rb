require "rails_helper"

describe Sms::Gateway do
  before { Sms::Adapters::Log.deliveries.clear }

  it "uses the log adapter in test when no provider is configured" do
    allow(Rails.application.secrets).to receive(:sms).and_return(nil)

    result = Sms::Gateway.deliver(to: "+491711234567", text: "Ihr Code: 1234")

    expect(result).to be_success
    expect(Sms::Adapters::Log.deliveries).to eq [{ to: "+491711234567", text: "Ihr Code: 1234" }]
  end

  it "passes the configuration to the configured adapter" do
    config = { provider: "esendex", sender: "Stadt", esendex: { api_key: "key", account_reference: "EXDE1" } }
    allow(Rails.application.secrets).to receive(:sms).and_return(config)
    adapter = instance_double(Sms::Adapters::Esendex, deliver: Sms::Result.success(message_id: "id-1"))
    allow(Sms::Adapters::Esendex).to receive(:new).and_return(adapter)

    result = Sms::Gateway.deliver(to: "+491711234567", text: "Ihr Code: 1234")

    expect(result.message_id).to eq "id-1"
    expect(Sms::Adapters::Esendex).to have_received(:new).with(hash_including(sender: "Stadt"))
    expect(adapter).to have_received(:deliver).with(to: "+491711234567", text: "Ihr Code: 1234")
  end

  it "fails without sending for an unknown provider" do
    allow(Rails.application.secrets).to receive(:sms).and_return({ provider: "unknown" })

    result = Sms::Gateway.deliver(to: "+491711234567", text: "Ihr Code: 1234")

    expect(result).not_to be_success
    expect(Sms::Adapters::Log.deliveries).to be_empty
  end

  it "reports failures to Sentry without the phone number" do
    allow(Rails.application.secrets).to receive(:sms).and_return({ provider: "unknown" })
    allow(Sentry).to receive(:capture_message)

    Sms::Gateway.deliver(to: "+491711234567", text: "Ihr Code: 1234")

    expect(Sentry).to have_received(:capture_message).with(a_string_including("failed"), level: :error)
    expect(Sentry).not_to have_received(:capture_message).with(a_string_including("1711234567"), anything)
  end
end
