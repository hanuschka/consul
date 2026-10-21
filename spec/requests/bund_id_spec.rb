require "rails_helper"

describe "BundID" do
  before do
    stub_bund_id_secrets
    set_setting("feature.bund_id_login", true)
    https!
  end

  def start_bund_id_request(purpose: nil)
    get users_bund_id_send_request_path(purpose: purpose)
    RelayState.order(:id).last
  end

  def post_bund_id_response(relay_state, saml_response)
    post users_bund_id_process_response_path,
         params: { SAMLResponse: saml_response, RelayState: relay_state.token }
  end

  def response_for(relay_state, **options)
    bund_id_saml_response(in_response_to: relay_state.data["request_id"], **options)
  end

  def signed_in?
    get account_path
    response.successful?
  end

  def login_failed_message
    I18n.t("custom.users.omniauth.bund_id.login_failed")
  end

  def saml_request_document
    saml_request = Rack::Utils.parse_query(URI.parse(response.location).query)["SAMLRequest"]
    REXML::Document.new(Zlib::Inflate.new(-Zlib::MAX_WBITS).inflate(Base64.decode64(saml_request)))
  end

  def requested_authn_context
    REXML::XPath.first(saml_request_document, "//*[local-name()='AuthnContextClassRef']").text
  end

  describe "signing in" do
    let!(:user) { create(:user, email: "erika@example.org") }

    before do
      Identity.create!(user: user, provider: "bund_id", uid: bund_id_identity[:uid])
    end

    it "accepts any BundID login level" do
      get users_bund_id_send_request_path

      expect(requested_authn_context).to eq("STORK-QAA-Level-1")
    end

    it "asks BundID only for the attributes it uses" do
      get users_bund_id_send_request_path

      requested = REXML::XPath.match(saml_request_document, "//*[local-name()='RequestedAttribute']/@Name")
                              .map(&:value)
      expect(requested).to match_array(BundIdServices::ResponseProcessor::ATTRIBUTE_NAMES.values)
    end

    it "keeps only a summary without personal data on the identity" do
      relay_state = start_bund_id_request

      post_bund_id_response(relay_state, response_for(relay_state))

      auth_data = Identity.find_by!(provider: "bund_id").auth_data
      expect(auth_data.keys).to match_array(%w[verification_level auth_method attributes received_at])
      expect(auth_data["verification_level"]).to eq("STORK-QAA-Level-3")
      expect(auth_data["auth_method"]).to eq("eID")
      expect(auth_data["attributes"]).to include("first_name", "postal_code")
      expect(auth_data.to_json).not_to include("Erika", "Heidestraße", "1964")
    end

    it "signs the user in with a response BundID signed for this request" do
      relay_state = start_bund_id_request

      post_bund_id_response(relay_state, response_for(relay_state))

      expect(signed_in?).to be true
    end

    it "does not sign anyone in with a response BundID never signed" do
      relay_state = start_bund_id_request

      post_bund_id_response(relay_state, response_for(relay_state, signed_by: :attacker))

      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to eq(login_failed_message)
      expect(signed_in?).to be false
    end

    it "rejects a response that answers a different request" do
      relay_state = start_bund_id_request

      post_bund_id_response(relay_state, bund_id_saml_response(in_response_to: "_another_request"))

      expect(flash[:alert]).to eq(login_failed_message)
      expect(signed_in?).to be false
    end

    it "rejects a response that comes back in a different browser" do
      relay_state = start_bund_id_request
      saml_response = response_for(relay_state)
      reset!
      https!

      post_bund_id_response(relay_state, saml_response)

      expect(flash[:alert]).to eq(login_failed_message)
      expect(signed_in?).to be false
    end

    it "rejects a response that was already used" do
      relay_state = start_bund_id_request
      browser_cookie = cookies[:bund_id_relay_state]
      saml_response = response_for(relay_state)
      post_bund_id_response(relay_state, saml_response)
      delete destroy_user_session_path

      cookies[:bund_id_relay_state] = browser_cookie
      post_bund_id_response(relay_state, saml_response)

      expect(flash[:alert]).to eq(login_failed_message)
      expect(signed_in?).to be false
    end

    describe "into a verified account" do
      let!(:geozone) { Geozone.create!(name: "Porz", postal_codes: "51147") }
      let(:old_address) do
        create(:registered_address, street_name: "Altstraße", plz: "50667", city_name: "Köln")
      end

      before do
        user.update_columns(first_name: "Max", last_name: "Mustermann", date_of_birth: Date.new(1964, 8, 12),
                            plz: 50667, verified_at: 1.year.ago, registered_address_id: old_address.id,
                            unique_stamp: "max_mustermann_1964_08_12_50667")
      end

      it "takes over the data of an ID-card login and recomputes what verification derived from it" do
        relay_state = start_bund_id_request

        post_bund_id_response(relay_state, response_for(relay_state))

        user.reload
        expect(user.first_name).to eq("Erika")
        expect(user.plz).to eq(51147)
        expect(user.unique_stamp).to eq("erika_mustermann_1964_08_12_51147")
        expect(user.geozone).to eq(geozone)
        expect(user).to be_level_three_verified
      end

      it "links the registered address that matches the new address" do
        new_address = create(:registered_address, street_name: "Heidestraße", street_number: "17",
                                                  plz: "51147", city_name: "Köln")
        relay_state = start_bund_id_request

        post_bund_id_response(relay_state, response_for(relay_state))

        expect(user.reload.registered_address_id).to eq(new_address.id)
      end

      it "clears the registered address when the new address is not a registered one" do
        relay_state = start_bund_id_request

        post_bund_id_response(relay_state, response_for(relay_state))

        expect(user.reload.registered_address_id).to be_nil
      end

      it "keeps the verified data on a username login" do
        relay_state = start_bund_id_request
        username_login = bund_id_identity(verification_level: "STORK-QAA-Level-1")

        post_bund_id_response(relay_state, response_for(relay_state, identity: username_login))

        user.reload
        expect(user.first_name).to eq("Max")
        expect(user.plz).to eq(50667)
        expect(user.unique_stamp).to eq("max_mustermann_1964_08_12_50667")
        expect(user.registered_address_id).to eq(old_address.id)
        expect(user.last_stork_level).to eq("STORK-QAA-Level-1")
      end

      it "keeps the verified data when the new data belongs to another verified account" do
        create(:user, :verified, unique_stamp: "erika_mustermann_1964_08_12_51147")
        relay_state = start_bund_id_request

        post_bund_id_response(relay_state, response_for(relay_state))

        user.reload
        expect(user.first_name).to eq("Max")
        expect(user.unique_stamp).to eq("max_mustermann_1964_08_12_50667")
        expect(user.registered_address_id).to eq(old_address.id)
        expect(user.geozone).to be_nil
      end
    end
  end

  describe "verifying an account" do
    let(:user) { create(:user, first_name: "Max") }

    before do
      set_setting("feature.bund_id_verification", true)
      sign_in(user)
    end

    it "asks BundID for an ID-card level login" do
      get users_bund_id_send_request_path(purpose: "verification")

      expect(requested_authn_context).to eq("STORK-QAA-Level-3")
    end

    it "verifies the account with a Level 3 response BundID signed for this request" do
      relay_state = start_bund_id_request(purpose: "verification")

      post_bund_id_response(relay_state, response_for(relay_state))

      expect(user.reload).to be_level_three_verified
      expect(user.first_name).to eq("Erika")
      expect(Identity.find_by(provider: "bund_id", uid: bund_id_identity[:uid]).user).to eq(user)
    end

    it "refuses to verify the account with a BundID identity that belongs to another account" do
      Identity.create!(user: create(:user), provider: "bund_id", uid: bund_id_identity[:uid])
      relay_state = start_bund_id_request(purpose: "verification")

      post_bund_id_response(relay_state, response_for(relay_state))

      expect(flash[:alert]).to eq(I18n.t("custom.users.omniauth.identity_taken"))
      expect(user.reload).not_to be_level_three_verified
      expect(user.first_name).to eq("Max")
    end

    it "does not link the BundID identity when the login was below ID-card level" do
      relay_state = start_bund_id_request(purpose: "verification")
      username_login = bund_id_identity(verification_level: "STORK-QAA-Level-1")

      post_bund_id_response(relay_state, response_for(relay_state, identity: username_login))

      expect(user.reload).not_to be_level_three_verified
      expect(Identity.where(provider: "bund_id")).to be_empty
    end

    it "does not verify the account with a response BundID never signed" do
      relay_state = start_bund_id_request(purpose: "verification")

      post_bund_id_response(relay_state, response_for(relay_state, signed_by: :attacker))

      expect(flash[:alert]).to eq(login_failed_message)
      expect(user.reload).not_to be_level_three_verified
      expect(user.first_name).to eq("Max")
    end

    it "does not verify the account when the response comes back in a different browser" do
      relay_state = start_bund_id_request(purpose: "verification")
      saml_response = response_for(relay_state)
      reset!
      https!

      post_bund_id_response(relay_state, saml_response)

      expect(user.reload).not_to be_level_three_verified
      expect(user.first_name).to eq("Max")
    end
  end

  describe "feature switches" do
    it "does not start a login while BundID login is switched off" do
      set_setting("feature.bund_id_login", false)

      expect { get users_bund_id_send_request_path }.to raise_error(ActionController::RoutingError)
      expect(RelayState.count).to eq(0)
    end

    it "does not start a verification while BundID verification is switched off" do
      set_setting("feature.bund_id_verification", false)
      sign_in(create(:user))

      expect do
        get users_bund_id_send_request_path(purpose: "verification")
      end.to raise_error(ActionController::RoutingError)
      expect(RelayState.count).to eq(0)
    end

    it "does not verify an account once BundID verification has been switched off" do
      user = create(:user, first_name: "Max")
      set_setting("feature.bund_id_verification", true)
      sign_in(user)
      relay_state = start_bund_id_request(purpose: "verification")
      set_setting("feature.bund_id_verification", false)

      expect do
        post_bund_id_response(relay_state, response_for(relay_state))
      end.to raise_error(ActionController::RoutingError)
      expect(user.reload).not_to be_level_three_verified
      expect(user.first_name).to eq("Max")
    end
  end

  describe "housekeeping" do
    it "deletes expired relay states when a new BundID request starts" do
      expired = RelayState.create!(token: "expired", created_at: 61.minutes.ago)
      active = RelayState.create!(token: "active", created_at: 59.minutes.ago)

      get users_bund_id_send_request_path

      expect(RelayState.exists?(expired.id)).to be false
      expect(RelayState.exists?(active.id)).to be true
    end

    it "rejects a response that comes back more than an hour after the request started" do
      relay_state = start_bund_id_request
      saml_response = response_for(relay_state, valid_until: 2.hours.from_now)
      browser_cookie = cookies[:bund_id_relay_state]

      travel(61.minutes) do
        cookies[:bund_id_relay_state] = browser_cookie
        post_bund_id_response(relay_state, saml_response)
      end

      expect(flash[:alert]).to eq(login_failed_message)
    end

    it "keeps the SAML response and relay state out of the logs" do
      filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

      filtered = filter.filter("SAMLResponse" => "PHNhbWxwOlJlc3BvbnNl", "RelayState" => "0123abcd")

      expect(filtered.values).to all(eq("[FILTERED]"))
    end
  end
end
