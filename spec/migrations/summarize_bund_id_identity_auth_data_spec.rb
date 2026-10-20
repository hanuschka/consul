require "rails_helper"
require Rails.root.join("db/migrate/20261014125228_summarize_bund_id_identity_auth_data")

describe SummarizeBundIdIdentityAuthData do
  let(:user) { create(:user) }
  let(:stored_bund_id_data) do
    {
      provider: "bund_id",
      uid: "bpk2-erika-mustermann",
      info: { email: "erika@example.org", first_name: "Erika", last_name: "Mustermann" },
      extra: {
        raw_info: {
          first_name: "Erika",
          last_name: "Mustermann",
          date_of_birth: "1964-08-12",
          street_address: "Heidestraße 17",
          place_of_birth: "Berlin",
          country: nil,
          auth_method: "eID",
          verification_level: "STORK-QAA-Level-3"
        }
      }
    }
  end

  def migrate
    ActiveRecord::Migration.suppress_messages { SummarizeBundIdIdentityAuthData.new.up }
  end

  it "replaces the stored BundID data with a summary without personal data" do
    identity = Identity.create!(user: user, provider: "bund_id", uid: "bpk2-erika-mustermann",
                                auth_data: stored_bund_id_data)

    migrate

    auth_data = identity.reload.auth_data
    expect(auth_data["verification_level"]).to eq("STORK-QAA-Level-3")
    expect(auth_data["auth_method"]).to eq("eID")
    expect(auth_data["attributes"]).to eq(
      %w[auth_method date_of_birth first_name last_name place_of_birth street_address verification_level]
    )
    expect(auth_data.to_json).not_to include("Erika", "Heidestraße", "Berlin", "1964")
  end

  it "leaves identities of other providers and already summarized ones alone" do
    other = Identity.create!(user: user, provider: "kobil", uid: "kobil-1", auth_data: stored_bund_id_data)
    summary = { "verification_level" => "STORK-QAA-Level-1", "attributes" => ["first_name"] }
    summarized = Identity.create!(user: create(:user), provider: "bund_id", uid: "bpk2-other",
                                  auth_data: summary)

    migrate

    expect(other.reload.auth_data.dig("extra", "raw_info", "first_name")).to eq("Erika")
    expect(summarized.reload.auth_data).to eq(summary)
  end
end
