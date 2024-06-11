# custom

require "rails_helper"

describe Users::OmniauthCallbacksController do
  describe "POST /bund_id_response" do
    let(:saml_response) { "mock_saml_response" }
    let(:params) { { SAMLResponse: saml_response } }
    let(:formatted_attributes) do
      { provider: "bund_id",
        uid: "IbGOjxZbiLRuntP_bK9vHcd6scbl8FGq23nR3MCPI-c",
        info: {
          email: "bundidtest@demokratie.today",
          name: "Asterix Gallier",
          first_name: "Asterix",
          last_name: "Gallier",
          verified_email: "michael+bundidtest_development@demokratie.today"
        },
        extra: {
          raw_info: {
            id: "IbGOjxZbiLRuntP_bK9vHcd6scbl8FGq23nR3MCPI-c",
            name: "Asterix Gallier",
            first_name: "Asterix",
            last_name: "Gallier",
            gender: "male",
            email: "michael+bundidtest_development@demokratie.today",
            auth_method: "Benutzername",
            date_of_birth: "2000-01-01",
            street_address: "Strasse, 333",
            locality_name: "Ort",
            country: "FR",
            postal_code: "12345",
            place_of_birth: "Bretagne",
            verification_level: "STORK-QAA-Level-1"
          }
        }
      }
    end
    let(:auth_data) { OmniAuth::AuthHash.new(formatted_attributes) }

    before do
      Setting["feature.bund_id_login"] = true
      allow(BundIdServices::ResponseProcessor).to receive(:call).with(saml_response).and_return(auth_data)
    end

    after do
      Setting["feature.bund_id_login"] = false
    end

    context "when the user doesn't exist" do
      it "creates a new user" do
        expect { post users_bund_id_process_response_path, params: params }.to change(User, :count).by(1)
      end

      it "create a new identity" do
        expect { post users_bund_id_process_response_path, params: params }.to change(Identity, :count).by(1)
      end

      it "stores auth_data in identity" do
        post users_bund_id_process_response_path, params: params

        expect(Identity.count).to eq(1)
        expect(Identity.last).to have_attributes(
          provider: "bund_id",
          uid: "IbGOjxZbiLRuntP_bK9vHcd6scbl8FGq23nR3MCPI-c",
          auth_data: auth_data
        )
      end

      it "doesn't verify the user when STORK-QAA-Level-1" do
        formatted_attributes[:extra][:raw_info][:verification_level] = "STORK-QAA-Level-1"
        auth_data = OmniAuth::AuthHash.new(formatted_attributes)
        allow(BundIdServices::ResponseProcessor).to receive(:call).with(saml_response).and_return(auth_data)

        post users_bund_id_process_response_path, params: params

        expect(User.last.verified_at).to be_nil
      end

      it "doesn't verify the user when STORK-QAA-Level-2" do
        formatted_attributes[:extra][:raw_info][:verification_level] = "STORK-QAA-Level-2"
        auth_data = OmniAuth::AuthHash.new(formatted_attributes)
        allow(BundIdServices::ResponseProcessor).to receive(:call).with(saml_response).and_return(auth_data)

        post users_bund_id_process_response_path, params: params

        expect(User.last.verified_at).to be_nil
      end

      it "verifies the user when STORK-QAA-Level-3" do
        formatted_attributes[:extra][:raw_info][:verification_level] = "STORK-QAA-Level-3"
        auth_data = OmniAuth::AuthHash.new(formatted_attributes)
        allow(BundIdServices::ResponseProcessor).to receive(:call).with(saml_response).and_return(auth_data)

        post users_bund_id_process_response_path, params: params

        expect(User.last.verified_at).not_to be_nil
      end

      it "verifies the user when STORK-QAA-Level-4" do
        formatted_attributes[:extra][:raw_info][:verification_level] = "STORK-QAA-Level-4"
        auth_data = OmniAuth::AuthHash.new(formatted_attributes)
        allow(BundIdServices::ResponseProcessor).to receive(:call).with(saml_response).and_return(auth_data)

        post users_bund_id_process_response_path, params: params

        expect(User.last.verified_at).not_to be_nil
      end

      it "links a corresponding RegisteredAddress to user when possible" do
        formatted_attributes[:extra][:raw_info][:street_address] = "Strasse, 333"
        formatted_attributes[:extra][:raw_info][:locality_name] = "Ort"
        formatted_attributes[:extra][:raw_info][:postal_code] = "12345"
        formatted_attributes[:extra][:raw_info][:country] = "DE"
        auth_data = OmniAuth::AuthHash.new(formatted_attributes)
        allow(BundIdServices::ResponseProcessor).to receive(:call).with(saml_response).and_return(auth_data)

        registered_address_attributes = {
          city_name: "Ort",
          plz: "12345",
          street_name: "Strasse",
          street_number: "333"
        }
        registered_address = create(:registered_address, registered_address_attributes)

        post users_bund_id_process_response_path, params: params

        expect(User.last.registered_address).to eq(registered_address)
      end

      it "stores address data, when registered is not found" do
        formatted_attributes[:extra][:raw_info][:street_address] = "EHM-WELK-STRAẞE 33"
        formatted_attributes[:extra][:raw_info][:locality_name] = "Ort"
        formatted_attributes[:extra][:raw_info][:postal_code] = "12345"
        formatted_attributes[:extra][:raw_info][:country] = "DE"
        auth_data = OmniAuth::AuthHash.new(formatted_attributes)
        allow(BundIdServices::ResponseProcessor).to receive(:call).with(saml_response).and_return(auth_data)

        post users_bund_id_process_response_path, params: params

        expect(User.last).to have_attributes(
          registered_address_id: nil,
          street_name: "EHM-WELK-STRAẞE",
          street_number: "33",
          city_name: "Ort",
          plz: 12345
        )

      end
    end

    context "when user with the same identity exists" do
      let(:user) { create(:user) }
      let!(:identity) { create(:identity, user: user, provider: "bund_id", uid: "IbGOjxZbiLRuntP_bK9vHcd6scbl8FGq23nR3MCPI-c", auth_data: "") }

      it "doesn't create a new user" do
        expect { post users_bund_id_process_response_path, params: params }.not_to change(User, :count)
      end

      it "doesn't create a new identity" do
        expect { post users_bund_id_process_response_path, params: params }.not_to change(Identity, :count)
      end

      it "stores auth_data in identity" do
        post users_bund_id_process_response_path, params: params

        expect(Identity.count).to eq(1)
        expect(Identity.last).to have_attributes(
          provider: "bund_id",
          uid: "IbGOjxZbiLRuntP_bK9vHcd6scbl8FGq23nR3MCPI-c",
          auth_data: auth_data
        )
      end
    end

    context "when user with the same email exists without identity" do
      let!(:user) { create(:user, email: "bundidtest@demokratie.today") }

      it "doesn't create a new user" do
        expect { post users_bund_id_process_response_path, params: params }.not_to change(User, :count)
      end

      it "creates a new identity" do
        expect { post users_bund_id_process_response_path, params: params }.to change(Identity, :count).by(1)
      end

      it "stores auth_data in identity" do
        post users_bund_id_process_response_path, params: params

        expect(Identity.count).to eq(1)
        expect(Identity.last).to have_attributes(
          provider: "bund_id",
          uid: "IbGOjxZbiLRuntP_bK9vHcd6scbl8FGq23nR3MCPI-c",
          auth_data: auth_data
        )
      end
    end
  end
end
