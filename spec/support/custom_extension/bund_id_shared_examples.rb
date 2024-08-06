RSpec.shared_examples "bund_id_examples_for_any_context" do
  it "updates auth_data in identity" do
    post users_bund_id_process_response_path, params: params

    expect(Identity.count).to eq(1)
    expect(Identity.last).to have_attributes(
      provider: "bund_id",
      uid: "IbGOjxZbiLRuntP_bK9vHcd6scbl8FGq23nR3MCPI-c",
      auth_data: auth_data
    )
  end

  it "links a corresponding RegisteredAddress to user when possible and STORK-QAA-Level-3" do
    formatted_attributes[:extra][:raw_info][:street_address] = "STRASSE, 333"
    formatted_attributes[:extra][:raw_info][:locality_name] = "ORT"
    formatted_attributes[:extra][:raw_info][:postal_code] = "12345"
    formatted_attributes[:extra][:raw_info][:country] = "DE"
    formatted_attributes[:extra][:raw_info][:verification_level] = "STORK-QAA-Level-3"
    auth_data = OmniAuth::AuthHash.new(formatted_attributes)
    allow(BundIdServices::ResponseProcessor).to receive(:call).with(saml_response).and_return(auth_data)

    registered_address_attributes = {
      city_name: "Ort",
      plz: "12345",
      street_name: "Straße",
      street_number: "333"
    }
    registered_address = create(:registered_address, registered_address_attributes)

    post users_bund_id_process_response_path, params: params

    expect(User.last.registered_address).to eq(registered_address)
  end

  it "links a corresponding RegisteredAddress to user when possible and STORK-QAA-Level-4" do
    formatted_attributes[:extra][:raw_info][:street_address] = "STRASSE, 333"
    formatted_attributes[:extra][:raw_info][:locality_name] = "ORT"
    formatted_attributes[:extra][:raw_info][:postal_code] = "12345"
    formatted_attributes[:extra][:raw_info][:country] = "DE"
    formatted_attributes[:extra][:raw_info][:verification_level] = "STORK-QAA-Level-4"
    auth_data = OmniAuth::AuthHash.new(formatted_attributes)
    allow(BundIdServices::ResponseProcessor).to receive(:call).with(saml_response).and_return(auth_data)

    registered_address_attributes = {
      city_name: "Ort",
      plz: "12345",
      street_name: "Straße",
      street_number: "333"
    }
    registered_address = create(:registered_address, registered_address_attributes)

    post users_bund_id_process_response_path, params: params

    expect(User.last.registered_address).to eq(registered_address)
  end

  it "saves address data, when registered address is not found and STORK-QAA-Level-3" do
    formatted_attributes[:extra][:raw_info][:street_address] = "EHM-WELK-STRASSE 33"
    formatted_attributes[:extra][:raw_info][:locality_name] = "ORT"
    formatted_attributes[:extra][:raw_info][:postal_code] = "12345"
    formatted_attributes[:extra][:raw_info][:country] = "DE"
    formatted_attributes[:extra][:raw_info][:verification_level] = "STORK-QAA-Level-3"
    auth_data = OmniAuth::AuthHash.new(formatted_attributes)
    allow(BundIdServices::ResponseProcessor).to receive(:call).with(saml_response).and_return(auth_data)

    post users_bund_id_process_response_path, params: params

    expect(User.last).to have_attributes(
      registered_address_id: nil,
      street_name: "Ehm-welk-straße",
      street_number: "33",
      city_name: "Ort",
      plz: 12345
    )
  end

  it "saves address data, when registered address is not found and STORK-QAA-Level-4" do
    formatted_attributes[:extra][:raw_info][:street_address] = "EHM-WELK-STRASSE 33"
    formatted_attributes[:extra][:raw_info][:locality_name] = "ORT"
    formatted_attributes[:extra][:raw_info][:postal_code] = "12345"
    formatted_attributes[:extra][:raw_info][:country] = "DE"
    formatted_attributes[:extra][:raw_info][:verification_level] = "STORK-QAA-Level-4"
    auth_data = OmniAuth::AuthHash.new(formatted_attributes)
    allow(BundIdServices::ResponseProcessor).to receive(:call).with(saml_response).and_return(auth_data)

    post users_bund_id_process_response_path, params: params

    expect(User.last).to have_attributes(
      registered_address_id: nil,
      street_name: "Ehm-welk-straße",
      street_number: "33",
      city_name: "Ort",
      plz: 12345
    )
  end

  it "saves last STORK verification level" do
    formatted_attributes[:extra][:raw_info][:verification_level] = "STORK-QAA-Level-3"
    auth_data = OmniAuth::AuthHash.new(formatted_attributes)
    allow(BundIdServices::ResponseProcessor).to receive(:call).with(saml_response).and_return(auth_data)

    post users_bund_id_process_response_path, params: params

    expect(User.last.last_stork_level).to eq("STORK-QAA-Level-3")
  end
end
