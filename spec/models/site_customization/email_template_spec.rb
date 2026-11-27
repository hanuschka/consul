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

  describe ".find_template" do
    around do |example|
      default_locale = I18n.default_locale
      I18n.default_locale = :de
      example.run
    ensure
      I18n.default_locale = default_locale
    end

    def customize(locale, body)
      described_class.create!(mailer_class: "Mailer", mailer_action: "resource_hidden", locale: locale, body: body)
    end

    def find(locale)
      described_class.find_template(nil, "Mailer", "resource_hidden", locale)
    end

    it "uses the template customized for the recipient's language" do
      customize("de", "<p>Deutsch</p>")
      customize("en", "<p>English</p>")

      expect(find("en").body).to eq "<p>English</p>"
    end

    it "falls back to the template customized in the default language" do
      customize("de", "<p>Deutsch</p>")
      customize("en", "")

      expect(find("en").body).to eq "<p>Deutsch</p>"
    end

    it "uses the default email when no language is customized" do
      customize("de", "")

      expect(find("en")).to be_nil
      expect(find("de")).to be_nil
    end
  end
end
