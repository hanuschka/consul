require "rails_helper"
require 'webmock/rspec'

describe "Login" do
  context "with BundID" do
    before do
      Setting["feature.bund_id_login"] = true
      # allow(BundIdServices::RedirectRequestMaker).to receive(:call).and_return("http://int.id.bund.de")
      # stub_request(:post, "http://localhost:3000/sp/SAML2/POST").to_return(body: "redirected", status: 200)
      allow(BundIdServices::ResponseProcessor).to receive(:call).and_return(bund_id_hash)
    end

    let(:bund_id_hash) do
      OmniAuth::AuthHash.new(
        {
          provider: "bund_id",
          uid: "abcdef",
          info: {
            email: "bund_id@demokratie.today",
            name: "Erika Mustermann",
            first_name: "Erika",
            last_name: "Mustermann",
            verified_email: "bund_id@demokratie.today",
            identity_verified: true
          },
          extra: {
            raw_info: {
              id: "abcdef",
              name: "Erika Mustermann",
              first_name: "Erika",
              last_name: "Mustermann",
              gender: "male",
              email: "bund_id@demokratie.today",
              auth_method: "Benutzername",
              date_of_birth: "2000-12-31",
              street_address: "Strasse, 123a",
              locality_name: "Berlin",
              country: "DE",
              postal_code: "12345",
              place_of_birth: "Brandenburg",
              verification_level: "STORK-QAA-Level-3"
            }
          }
        }
      )
    end

    context "when user signs in with BundID for the first time" do
      fit "signs in user successfully when email is not taken" do
        post "/sp/SAML2/POST", params: { SAMLRequest: "request" }

        visit new_user_session_path(locale: :de)
        # click_link(title: "Login with BundId")
        debugge
        expect(page).to have_content "Erfolgreich angemeldet."
        expect(User.count).to eq(1)
        expect(User.first.keycloak_link).to eq("johndoe")
        expect(User.first.email).to eq("bayern_id@consul.dev")
      end

      # context "Consul user that signed in with email before" do
      #   it "can logout successfully" do
      #     user = create(:user, email: "consul@consul.dev", keycloak_link: nil, password: "12345678")
      #     login_as(user)
      #     visit root_path(locale: :de)
      #     click_button "Alle akzeptieren"
      #     find(".account-items-icon").find(:xpath, "..").hover
      #     click_link "Abmelden"
      #     expect(page).to have_content "Sie haben sich erfolgreich abgemeldet."
      #   end
      # end

      # context "when user with the same email coming from Keycloak is already taken in Consul" do
      #   it "redirects to sign in page and asks user to sign in with email" do
      #     create(:user, email: "bayern_id@consul.dev", keycloak_link: nil)
      #     visit new_user_session_path(locale: :de)
      #     click_button "Alle akzeptieren"
      #     click_link(title: "Anmelden mit BayernID")
      #     expect(page).to have_content "Die angegebene E-Mail-Adresse wird bereits verwendet."
      #     expect(User.count).to eq(1)
      #     expect(User.first.keycloak_link).to eq(nil)
      #     expect(User.first.email).to eq("bayern_id@consul.dev")
      #   end
      # end

      # context "when user's first and last name form a username that is already taken" do
      #   before do
      #     create(:user, username: "John Doe")
      #   end

      #   it "signs in user successfully and allows to pick a different username" do
      #     visit new_user_session_path(locale: :de)
      #     click_button "Alle akzeptieren"
      #     click_link(title: "Anmelden mit BayernID")

      #     expect(page).to have_current_path("/finish_signup")

      #     fill_in "Benutzer*innenname", with: "John Doe 2"
      #     click_button "Registrieren"

      #     expect(User.count).to eq(2)
      #     expect(User.last.keycloak_link).to eq("johndoe")
      #     expect(User.last.username).to eq("John Doe 2")
      #   end
      # end
    end

    # context "when user was blocked by admin" do
    #   it "prevents user from signing in" do
    #     create(:user, email: "bayern_id@consul.dev", hidden_at: Time.current)
    #     visit new_user_session_path(locale: :de)
    #     click_button "Alle akzeptieren"
    #     click_link(title: "Anmelden mit BayernID")
    #     expect(page).to have_content "Dieses Nutzerkonto existiert bereits, wurde aber von einem Moderator geblockt."
    #     expect(User.count).to eq(0)
    #     expect(User.with_hidden.count).to eq(1)
    #   end
    # end

    # context "when user's username was duplicate but user didn't complete registration to update the username" do
    #   before do
    #     create(:user, username: "John Doe" )
    #     create(:user, username: "John Doe", email: "bayern_id@consul.dev", oauth_email: "bayern_id@consul.dev", keycloak_link: "johndoe", registering_with_oauth: true)
    #   end

    #   it "redirects user to finish sign_up_path and allows updating username" do
    #     visit new_user_session_path(locale: :de)
    #     click_button "Alle akzeptieren"
    #     click_link(title: "Anmelden mit BayernID")

    #     expect(page).to have_current_path("/finish_signup")
    #     expect(page).to have_content "1 Fehler verhinderte das Speichern dieser Konto"

    #     fill_in "Benutzer*innenname", with: "John Doe new"
    #     click_button "Registrieren"

    #     expect(User.count).to eq(2)

    #     expect(page).to have_content "Erfolgreich angemeldet."

    #     expect(User.first).to have_attributes(
    #       username: "John Doe",
    #       registering_with_oauth: false
    #     )
    #     expect(User.last).to have_attributes(
    #       username: "John Doe new",
    #       registering_with_oauth: false,
    #       keycloak_link: "johndoe"
    #     )
    #   end
    # end

    # context "when user signed in with keycloak before" do
    #   context "without changing his email address in keycloak after first sign in to Consul" do
    #     it "signs user in successfully" do
    #       create(:user, email: "bayern_id@consul.dev", keycloak_link: "johndoe")
    #       visit new_user_session_path(locale: :de)
    #       click_button "Alle akzeptieren"
    #       click_link(title: "Anmelden mit BayernID")
    #       expect(page).to have_content "Erfolgreich angemeldet."
    #       expect(User.count).to eq(1)
    #       expect(User.first.keycloak_link).to eq("johndoe")
    #       expect(User.first.email).to eq("bayern_id@consul.dev")
    #     end
    #   end

    #   context "when email address was changed in keycloak after first sign in to Consul" do
    #     it "prevents user from signing in when new email is already taken" do
    #       create(:user, email: "bayern_id_old@consul.dev", keycloak_link: "johndoe")
    #       create(:user, email: "bayern_id@consul.dev")
    #       visit new_user_session_path(locale: :de)
    #       click_button "Alle akzeptieren"
    #       click_link(title: "Anmelden mit BayernID")
    #       expect(page).to have_content "Die angegebene E-Mail-Adresse wird bereits verwendet."
    #       expect(User.count).to eq(2)
    #     end

    #     it "signs user in and updates existing user's email address when new email is not taken" do
    #       create(:user, email: "bayern_id_old@consul.dev", keycloak_link: "johndoe")
    #       visit new_user_session_path(locale: :de)
    #       click_button "Alle akzeptieren"
    #       click_link(title: "Anmelden mit BayernID")
    #       expect(page).to have_content "Erfolgreich angemeldet."
    #       expect(User.count).to eq(1)
    #       expect(User.first.email).to eq("bayern_id@consul.dev")
    #     end
    #   end
    # end
  end
end
