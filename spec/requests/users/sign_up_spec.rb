require "rails_helper"

describe "Sign-up", type: :request do
  let(:email) { "lena.vogt@example.org" }

  let(:base_params) do
    {
      username: "Lena Vogt",
      email: email,
      password: "Aa12345678!",
      password_confirmation: "Aa12345678!",
      terms_data_storage: "1",
      terms_data_protection: "1",
      terms_general: "1"
    }
  end

  let(:extended_params) do
    {
      first_name: "Lena",
      last_name: "Vogt",
      gender: "female",
      date_of_birth: "1990-05-01",
      city_name: "München",
      plz: "80331",
      street_name: "Marienplatz",
      street_number: "1"
    }
  end

  before do
    set_setting("extra_fields.registration.extended", nil)
    set_setting("extra_fields.registration.check_documents", nil)
  end

  around do |example|
    InvisibleCaptcha.timestamp_enabled = false
    example.run
    InvisibleCaptcha.timestamp_enabled = true
  end

  def sign_up(user_params = {}, extra_params = {})
    post user_registration_path, params: { user: base_params.merge(user_params) }.merge(extra_params)
  end

  describe "basic registration" do
    it "creates an unconfirmed account, sends the confirmation email and shows the success page" do
      expect { sign_up }
        .to change(User, :count).by(1)
        .and have_enqueued_mail(DeviseMailer, :confirmation_instructions)

      user = User.find_by!(email: email)
      expect(user).not_to be_confirmed
      expect(response).to redirect_to(users_sign_up_success_path)
    end

    it "rejects the sign-up when a terms checkbox is not ticked" do
      expect { sign_up(terms_general: "0") }.not_to change(User, :count)

      expect(response).to have_http_status(:ok)
    end

    it "rejects a password that fails the complexity rule" do
      expect { sign_up(password: "abcdefghij", password_confirmation: "abcdefghij") }
        .not_to change(User, :count)

      expect(response).to have_http_status(:ok)
    end

    it "confirms the account through the confirmation link" do
      sign_up
      user = User.find_by!(email: email)

      get user_confirmation_path(confirmation_token: user.confirmation_token)

      expect(user.reload).to be_confirmed
    end
  end

  describe "extended registration" do
    before { set_setting("extra_fields.registration.extended", true) }

    it "rejects the sign-up when the personal data is missing" do
      expect { sign_up }.not_to change(User, :count)

      expect(response).to have_http_status(:ok)
    end

    it "creates the account with the personal data" do
      expect { sign_up(extended_params) }.to change(User, :count).by(1)

      user = User.find_by!(email: email)
      expect(user).to have_attributes(first_name: "Lena", last_name: "Vogt", gender: "female",
                                      city_name: "München", plz: 80331)
      expect(user.date_of_birth.to_date).to eq Date.new(1990, 5, 1)
      expect(response).to redirect_to(users_sign_up_success_path)
    end

    context "when an account with the same name, date of birth and postcode exists" do
      let!(:existing) do
        build(:user, unique_stamp: "lena_vogt_1990_05_01_80331").tap { |user| user.save!(validate: false) }
      end

      it "does not create the account and notifies both addresses" do
        expect { sign_up(extended_params) }
          .to change(User, :count).by(0)
          .and have_enqueued_mail(Mailer, :existing_stamp_notify_existing_user).with(existing)
          .and have_enqueued_mail(Mailer, :existing_stamp_notify_new_user).with(email)

        expect(response).to redirect_to(new_user_registration_path)
        expect(flash[:alert])
          .to eq I18n.t("custom.devise_views.users.registrations.create.existing_user_with_same_stamp")
      end
    end
  end

  describe "registration through an invitation" do
    let!(:invitation) { PendingRoleAssignment.create!(email: email, role_type: "Administrator") }

    it "creates a confirmed account with the invited role and opens the admin area" do
      expect { sign_up({}, invitation_token: invitation.invitation_token) }.to change(User, :count).by(1)

      user = User.find_by!(email: email)
      expect(user).to be_confirmed
      expect(user).to be_administrator
      expect(response).to redirect_to(adm_root_path)
    end
  end
end
