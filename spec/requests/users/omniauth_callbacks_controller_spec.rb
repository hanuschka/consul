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
          verified_email: "bundidtest@demokratie.today"
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

    context "when user is logging in with BundID for the first time, while a corresponding Consul user with matching email address exists" do
      before do
        create(:user, email: "bundidtest@demokratie.today")
      end

      it "doesn't create a new user" do
        expect { post users_bund_id_process_response_path, params: params }.not_to change(User, :count)
      end

      it "creates a new identity" do
        expect { post users_bund_id_process_response_path, params: params }.to change(Identity, :count).by(1)
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

      include_examples "bund_id_examples_for_any_context"
    end

    context "when user is logging in with BundID for the first time, while a corresponding Consul user with matching email address DOES NOT exist" do
      it "creates a new user" do
        expect { post users_bund_id_process_response_path, params: params }.to change(User, :count).by(1)
      end

      it "create a new identity" do
        expect { post users_bund_id_process_response_path, params: params }.to change(Identity, :count).by(1)
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

      include_examples "bund_id_examples_for_any_context"
    end

    context "when user is logging in with BundID another time, (i.e. there is identity matching bund_id data)" do
      let(:user) { create(:user, email: "bundidtestold@demokratie.today") }
      let!(:identity) { create(:identity, user: user, provider: "bund_id", uid: "IbGOjxZbiLRuntP_bK9vHcd6scbl8FGq23nR3MCPI-c", auth_data: "") }

      it "doesn't create a new user" do
        expect { post users_bund_id_process_response_path, params: params }.not_to change(User, :count)
      end

      it "doesn't create a new identity" do
        expect { post users_bund_id_process_response_path, params: params }.not_to change(Identity, :count)
      end

      it "doesn't change user verification status when STORK-QAA-Level-1" do
        formatted_attributes[:extra][:raw_info][:verification_level] = "STORK-QAA-Level-1"
        auth_data = OmniAuth::AuthHash.new(formatted_attributes)
        allow(BundIdServices::ResponseProcessor).to receive(:call).with(saml_response).and_return(auth_data)

        expect { post users_bund_id_process_response_path, params: params }.not_to change { User.last.verified_at }
      end

      it "doesn't change user verification status when STORK-QAA-Level-2" do
        formatted_attributes[:extra][:raw_info][:verification_level] = "STORK-QAA-Level-2"
        auth_data = OmniAuth::AuthHash.new(formatted_attributes)
        allow(BundIdServices::ResponseProcessor).to receive(:call).with(saml_response).and_return(auth_data)

        expect { post users_bund_id_process_response_path, params: params }.not_to change { User.last.verified_at }
      end

      include_examples "bund_id_examples_for_any_context"

      context "when user changed email address in BundID" do

        before do
          formatted_attributes[:info][:email] = "newbundidtest@demokratie.today"
          auth_data = OmniAuth::AuthHash.new(formatted_attributes)
          allow(BundIdServices::ResponseProcessor).to receive(:call).with(saml_response).and_return(auth_data)
        end

        context "when new email is not taken in Consul" do
          it "updates the user's email" do
            expect { post users_bund_id_process_response_path, params: params }
              .to change { user.reload.email }.from("bundidtestold@demokratie.today").to("newbundidtest@demokratie.today")
          end

          it "shows notification with correct message" do
            post users_bund_id_process_response_path, params: params

            expect(flash[:notice]).to eq("Your email has been updated.")
          end
        end

        context "when new email is taken" do
          before do
            create(:user, email: "newbundidtest@demokratie.today")
          end

          it "doesn't update the user's email" do
            expect { post users_bund_id_process_response_path, params: params }
              .not_to change(user.reload, :email)
          end

          it "shows notification with correct message" do
            post users_bund_id_process_response_path, params: params

            expect(flash[:notice]).to eq("Email was taken. Please contact support.")
          end
        end
      end
    end
  end
end