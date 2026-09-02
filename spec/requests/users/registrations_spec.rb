require "rails_helper"

describe "Registration with an email that is already taken", type: :request do
  let(:taken_email) { "malte.specht@bad-belzig.de" }

  let(:registration_params) do
    {
      user: {
        username: "Projektleiter Smart City",
        email: taken_email,
        password: "Aa12345678!",
        password_confirmation: "Aa12345678!",
        terms_data_storage: "1",
        terms_data_protection: "1",
        terms_general: "1"
      }
    }
  end

  before do
    set_setting("extra_fields.registration.extended", nil)
    set_setting("extra_fields.registration.check_documents", nil)
  end

  # invisible_captcha rejects a POST whose session carries no timestamp, and the timestamp is only
  # planted by rendering the registration form. These examples post to the endpoint directly.
  around do |example|
    InvisibleCaptcha.timestamp_enabled = false
    example.run
    InvisibleCaptcha.timestamp_enabled = true
  end

  def register(email: taken_email)
    post user_registration_path, params: registration_params.deep_merge(user: { email: email })
  end

  context "when nothing holds the email" do
    it "creates the account" do
      expect { register(email: "free@example.org") }.to change(User, :count).by(1)
    end
  end

  context "when an unconfirmed account holds the email" do
    let!(:existing) { create(:user, :unconfirmed, email: taken_email) }

    it "does not create a second account" do
      expect { register }.not_to change(User, :count)
    end

    it "sends the confirmation email again" do
      expect { register }
        .to have_enqueued_mail(DeviseMailer, :confirmation_instructions).with(existing, anything, anything)
    end

    it "tells the user that the confirmation email was sent again" do
      register

      expect(response).to redirect_to(new_user_registration_path)
      expect(flash[:notice])
        .to eq I18n.t("custom.devise_views.users.registrations.create.email_taken_by_unconfirmed_account")
    end
  end

  # A confirmed account is left to the Devise uniqueness validation: the form comes back with the
  # field error it has always shown. Registration deliberately says nothing more, and mails nothing,
  # so it does not hand out any confirmation that the address belongs to an active account.
  context "when a confirmed account holds the email" do
    before { create(:user, email: taken_email) }

    it "does not create a second account" do
      expect { register }.not_to change(User, :count)
    end

    it "re-renders the registration form without sending any email" do
      expect { register }.not_to have_enqueued_mail(DeviseMailer, :confirmation_instructions)

      expect(response).to have_http_status(:ok)
    end
  end

  # A hidden account is invisible to the Devise uniqueness validation (the paranoia gem scopes it to
  # hidden_at IS NULL), so User#email_should_not_be_used_by_hidden_user handles that case on its own.
  # Registration must not treat it as an unconfirmed account and mail a blocked address.
  context "when a hidden account holds the email" do
    before { create(:user, email: taken_email, hidden_at: Time.current) }

    it "does not create a second account" do
      expect { register }.not_to change(User.with_hidden, :count)
    end

    it "sends no confirmation email to the blocked address" do
      expect { register }.not_to have_enqueued_mail(DeviseMailer, :confirmation_instructions)
    end
  end
end
