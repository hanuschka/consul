require "rails_helper"

describe SiteCustomization::EmailTemplate do
  describe "recipient name variables" do
    let(:recipient_name_variables) { %w[username last_name officer_name admin_name] }

    it "lists recipient_greeting instead of the recipient's name" do
      described_class::EMAIL_TEMPLATES.each do |key, config|
        expect(config[:variables] & recipient_name_variables).to be_empty, key
        expect(config[:variables]).to include("recipient_greeting"), key if config[:hidden_variables]
      end
    end

    it "keeps the replaced variables as hidden" do
      template = described_class.new(mailer_class: "NotificationServiceMailer",
                                     mailer_action: "user_reverification_failed")

      expect(template.registered_variables).to eq %w[recipient_greeting base_url]
      expect(template.hidden_variables).to eq %w[last_name]
    end
  end
end
