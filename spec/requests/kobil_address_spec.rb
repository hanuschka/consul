require "rails_helper"

describe "KOBIL login address", type: :request do
  let(:user) { create(:user) }
  let(:old_address) do
    create(:registered_address, street_name: "Altstraße", street_number: "1", plz: "50667", city_name: "Köln")
  end

  def kobil_auth(street_address:, postal_code: "51147", locality: "Köln")
    OmniAuth::AuthHash.new(
      provider: "kobil",
      uid: "kobil-erika",
      info: { first_name: "Erika", last_name: "Mustermann", email: user.email },
      extra: {
        raw_info: {
          birthdate: "1964-08-12",
          address: { "street_address" => street_address, "postal_code" => postal_code, "locality" => locality }
        }
      }
    )
  end

  def log_in_with_kobil(**address)
    OmniAuth.config.mock_auth[:kobil] = kobil_auth(**address)
    get user_kobil_omniauth_callback_path
  end

  before do
    set_setting("feature.kobil_login", true)
    set_setting("feature.kobil_address_verification", true)
    Identity.create!(user: user, provider: "kobil", uid: "kobil-erika")
    user.update_columns(registered_address_id: old_address.id, street_name: "Altstraße", street_number: "1",
                        plz: 50667, city_name: "Köln")
  end

  after { OmniAuth.config.mock_auth[:kobil] = nil }

  it "links the registered address that matches the KOBIL address" do
    new_address = create(:registered_address, street_name: "Heidestraße", street_number: "17",
                                              plz: "51147", city_name: "Köln")

    log_in_with_kobil(street_address: "Heidestraße 17")

    user.reload
    expect(user.registered_address_id).to eq(new_address.id)
    expect(user.street_name).to eq("Heidestraße")
    expect(user.street_number).to eq("17")
  end

  it "clears the old registered address when the KOBIL address is not a registered one" do
    log_in_with_kobil(street_address: "Heidestraße 17")

    user.reload
    expect(user.registered_address_id).to be_nil
    expect(user.street_name).to eq("Heidestraße")
    expect(user.street_number).to eq("17")
    expect(user.plz).to eq(51147)
  end

  it "leaves the address alone while KOBIL address verification is switched off" do
    set_setting("feature.kobil_address_verification", nil)

    log_in_with_kobil(street_address: "Heidestraße 17")

    user.reload
    expect(user.registered_address_id).to eq(old_address.id)
    expect(user.street_name).to eq("Altstraße")
  end
end
