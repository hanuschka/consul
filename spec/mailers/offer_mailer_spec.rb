require "rails_helper"

describe OfferMailer do
  let(:provider) { create(:offer_provider, name: "Sportverein Nord") }
  let(:user) { create(:user, username: "Anna Muster") }
  let!(:swimming) { create(:offer, provider: provider, title: "Schwimmkurs") }
  let!(:climbing) do
    create(:offer, provider: provider, title: "Kletterkurs", deactivated_at: Time.current)
  end

  before { ActionMailer::Base.deliveries.clear }

  describe "provider_reminder" do
    let(:mail) { OfferMailer.provider_reminder(provider, user) }

    it "goes to the user and names the provider" do
      expect(mail.to).to eq([user.email])
      expect(mail.subject).to include("Sportverein Nord")
    end

    it "has an html and a plain-text part" do
      expect(mail.html_part).to be_present
      expect(mail.text_part).to be_present
    end

    it "lists every offer with its title and edit link in both parts" do
      [mail.html_part, mail.text_part].each do |part|
        body = part.decoded

        expect(body).to include("Schwimmkurs")
        expect(body).to include("Kletterkurs")
        expect(body).to include(edit_offer_url(swimming, host: mail_host))
        expect(body).to include(edit_offer_url(climbing, host: mail_host))
      end
    end

    it "marks a deactivated offer" do
      scope = "custom.offer_mailer.provider_reminder"
      deactivated = I18n.t("#{scope}.states.deactivated")
      climbing_link = I18n.t("#{scope}.edit_link", title: "Kletterkurs")
      swimming_link = I18n.t("#{scope}.edit_link", title: "Schwimmkurs")

      expect(mail.text_part.decoded).to include("#{climbing_link} (#{deactivated})")
      expect(mail.text_part.decoded).not_to include("#{swimming_link} (")
      expect(mail.html_part.decoded).to include(deactivated)
    end

    it "sends nothing to a user without an address" do
      user.update_columns(email: nil)

      expect { OfferMailer.provider_reminder(provider, user).deliver_now }
        .not_to change { ActionMailer::Base.deliveries.count }
    end
  end

  def mail_host
    Rails.application.config.action_mailer.default_url_options[:host]
  end
end
