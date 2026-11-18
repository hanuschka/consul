require "rails_helper"

describe "Welcome email", type: :request do
  let(:user) { create(:user, :unconfirmed) }

  def confirm(token)
    get user_confirmation_path(confirmation_token: token)
  end

  it "is sent once when a registration is confirmed" do
    expect { confirm(user.confirmation_token) }.to have_enqueued_mail(Mailer, :welcome).once
    expect(user.reload.welcome_email_sent_at).to be_present
  end

  it "is not sent again after an OAuth e-mail change reset the confirmation" do
    welcomed_user = create(:user, welcome_email_sent_at: 1.month.ago)
    welcomed_user.update!(oauth_email: "anders@example.org")
    welcomed_user.send_oauth_confirmation_instructions

    expect(welcomed_user.reload.confirmed_at).to be_nil
    expect { confirm(welcomed_user.confirmation_token) }.not_to have_enqueued_mail(Mailer, :welcome)
  end

  it "is not sent again when a changed e-mail address is confirmed" do
    confirmed_user = create(:user)
    confirmed_user.update!(email: "neu@example.org")

    expect { confirm(confirmed_user.reload.confirmation_token) }.not_to have_enqueued_mail(Mailer, :welcome)
    expect(confirmed_user.reload.email).to eq "neu@example.org"
  end

  describe "registration through a role invitation" do
    let(:email) { "lena.vogt@example.org" }
    let!(:invitation) { PendingRoleAssignment.create!(email: email, role_type: "ProjektManager") }

    around do |example|
      InvisibleCaptcha.timestamp_enabled = false
      example.run
      InvisibleCaptcha.timestamp_enabled = true
    end

    it "is sent once although the account skips the confirmation step" do
      params = { user: { username: "Lena Vogt", email: email, password: "Aa12345678!",
                         password_confirmation: "Aa12345678!", terms_data_storage: "1",
                         terms_data_protection: "1", terms_general: "1" },
                 invitation_token: invitation.invitation_token }

      expect { post user_registration_path, params: params }.to have_enqueued_mail(Mailer, :welcome).once
      expect(User.find_by!(email: email)).to be_confirmed
    end
  end

  describe "registration through a login service" do
    let(:auth) do
      OmniAuth::AuthHash.new(
        provider: "kobil",
        uid: "kobil-lena",
        info: { first_name: "Lena", last_name: "Vogt", email: "lena.vogt@example.org", email_verified: true },
        extra: { raw_info: {} }
      )
    end

    before do
      set_setting("feature.kobil_login", true)
      OmniAuth.config.mock_auth[:kobil] = auth
    end

    after { OmniAuth.config.mock_auth[:kobil] = nil }

    it "is sent once for the new account and not on later logins" do
      expect { get user_kobil_omniauth_callback_path }.to have_enqueued_mail(Mailer, :welcome).once
      expect(User.find_by!(email: "lena.vogt@example.org")).to be_confirmed

      delete destroy_user_session_path

      expect { get user_kobil_omniauth_callback_path }.not_to have_enqueued_mail(Mailer, :welcome)
    end
  end

  describe "System-E-Mails page" do
    before do
      allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
      allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    end

    it "lists the welcome email for administrators" do
      login_as(create(:administrator).user)

      get adm_global_email_templates_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("mailer.welcome.title"))
    end

    it "is closed to other users" do
      login_as(create(:user))

      get adm_global_email_templates_path

      expect(response).not_to have_http_status(:ok)
      expect(response.body).not_to include(I18n.t("mailer.welcome.title"))
    end
  end
end
