require "rails_helper"

describe BrevoMemberMailer do
  let(:user) do
    create(:user, username: "Erika Musterfrau", email: "erika@example.org", locale: "de")
  end
  let(:mail) { BrevoMemberMailer.invitation(user, "raw-reset-token") }

  def body_of(mail)
    mail.body.decoded
  end

  def footer_block(body)
    SiteCustomization::ContentBlock.create!(
      name: "custom", key: "email_footer", locale: I18n.default_locale, body: body
    )
  end

  before do
    ActionMailer::Base.deliveries.clear
    Setting["org_name"] = "Mehr Demokratie e.V."
  end

  describe "#invitation" do
    it "goes to the member" do
      expect(mail.to).to eq([user.email])
      expect(mail.subject).to eq(I18n.t("custom.brevo_member.mailers.invitation.subject", locale: :de))
    end

    it "sends nothing without an address" do
      user.update_columns(email: nil)

      expect { mail.deliver_now }.not_to change(ActionMailer::Base.deliveries, :count)
    end

    it "greets the member by name and welcomes them to the organisation's members' area" do
      body = body_of(mail)

      expect(body).to include("Hallo Erika Musterfrau,")
      expect(body).to include("herzlich Willkommen im neuen Mitgliederbereich von Mehr Demokratie e.V.")
    end

    # "Mehr Demokratie e.V." already ends in a period; the abbreviation's dot ends the sentence.
    it "does not double the period after an organisation name that ends in one" do
      expect(body_of(mail)).not_to include("Mehr Demokratie e.V..")
    end

    it "ends the welcome sentence when the organisation name has no trailing period" do
      Setting["org_name"] = "Mehr Demokratie"

      expect(body_of(mail)).to include("Mitgliederbereich von Mehr Demokratie.")
    end

    it "explains why the account exists" do
      expect(body_of(mail)).to include(
        "Für Sie wurde ein Zugang zur Beteiligungsplattform angelegt, weil Ihre E-Mail-Adresse " \
        "erika@example.org in der Mitgliederliste des Vereins hinterlegt ist."
      )
    end

    it "carries the password link and the fallback to request a new one" do
      body = body_of(mail)

      expect(body).to include(edit_user_password_url(reset_password_token: "raw-reset-token"))
      expect(body).to include("Passwort vergeben")
      expect(body).to include(new_user_password_url)
      expect(body).to include("neuen Link anfordern")
    end

    it "signs off as the membership service" do
      body = body_of(mail)

      expect(body).to include("Freundliche Grüße")
      expect(body).to include("Ihr Team vom Mitgliederservice")
    end

    # The sign-off is the client's copy, not a stand-in for a missing footer, so it stays when the
    # instance fills in its own footer block.
    it "keeps the sign-off when a custom footer is configured" do
      footer_block("<p>Mehr Demokratie e.V., Tempelhof 3, 74594 Kreßberg</p>")
      body = body_of(mail)

      expect(body).to include("Ihr Team vom Mitgliederservice")
      expect(body).to include("Tempelhof 3")
    end

    it "drops the organisation line and the no-reply notice once a custom footer is configured" do
      footer_block("<p>Mehr Demokratie e.V., Tempelhof 3, 74594 Kreßberg</p>")
      body = body_of(mail)

      expect(body).not_to include(I18n.t("mailers.no_reply", locale: :de))
    end

    it "shows the default footer while no custom footer is configured" do
      expect(body_of(mail)).to include(I18n.t("mailers.no_reply", locale: :de))
    end
  end

  # The invitation links straight into the Devise password flow, so a member who waits too long
  # lands on a Devise mail — it has to carry the same footer and lose the same no-reply notice.
  describe "the password reset mail the invitation links to" do
    let(:reset_mail) { DeviseMailer.reset_password_instructions(user, "raw-reset-token") }

    it "carries the custom footer instead of the no-reply notice" do
      footer_block("<p>Mehr Demokratie e.V., Tempelhof 3, 74594 Kreßberg</p>")
      body = reset_mail.body.decoded

      expect(body).to include("Tempelhof 3")
      expect(body).not_to include(I18n.t("mailers.no_reply", locale: :de))
    end
  end
end
