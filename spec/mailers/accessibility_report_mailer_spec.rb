require "rails_helper"

describe AccessibilityReportMailer do
  let(:report_attributes) do
    { "location" => "/projekts/radweg", "description" => "Kontrast zu gering",
      "assistive_technology" => "NVDA", "email" => "kai@example.org" }
  end

  it "sends the report with every field to the configured address" do
    Setting["accessibility_report.recipient_email"] = "barrieren@stadt.example"

    mail = described_class.report_submitted(report_attributes)

    expect(mail.to).to eq ["barrieren@stadt.example"]
    expect(mail.bcc).to include("info@demokratie.today")
    expect(mail.reply_to).to eq ["kai@example.org"]
    expect(mail.body.encoded).to include("/projekts/radweg", "Kontrast zu gering", "NVDA", "kai@example.org")
  end

  it "sends the report to the administrators while no address is configured" do
    Setting["accessibility_report.recipient_email"] = ""
    admin = create(:administrator).user

    expect(described_class.report_submitted(report_attributes).to).to include(admin.email)
  end

  it "sends the reporter a confirmation" do
    expect(described_class.confirmation("kai@example.org", "de").to).to eq ["kai@example.org"]
  end
end
