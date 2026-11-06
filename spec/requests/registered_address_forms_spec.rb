require "rails_helper"

describe "Address forms keep the registered address and the typed address together", type: :request do
  let(:old_address) do
    create(:registered_address, street_name: "Altstraße", street_number: "1", plz: "50667", city_name: "Köln")
  end
  let(:new_address) do
    create(:registered_address, street_name: "Heidestraße", street_number: "17", plz: "51147", city_name: "Köln")
  end
  let(:user) do
    create(:user, registered_address_id: old_address.id, street_name: "Altstraße", street_number: "1",
                  plz: 50667, city_name: "Köln")
  end

  def picker_params(address)
    {
      form_registered_address_city_id: address.registered_address_city_id.to_s,
      form_registered_address_street_id: address.registered_address_street_id.to_s,
      form_registered_address_id: address.id.to_s
    }
  end

  def not_in_list_params
    { form_registered_address_city_id: "0", form_registered_address_street_id: "", form_registered_address_id: "" }
  end

  def typed_address(street_name: "Altstraße", street_number: "1", plz: "50667", city_name: "Köln")
    { street_name: street_name, street_number: street_number, street_number_extension: "",
      plz: plz, city_name: city_name }
  end

  describe "editing a user in /adm" do
    before { login_as(create(:administrator).user) }

    def update_user(params)
      patch adm_user_path(user), params: params
    end

    it "links the picked address and copies it into the typed address" do
      update_user(user: { email: user.email, **typed_address }, **picker_params(new_address))

      user.reload
      expect(user.registered_address_id).to eq(new_address.id)
      expect(user.street_name).to eq("Heidestraße")
      expect(user.street_number).to eq("17")
      expect(user.plz).to eq(51147)
    end

    it "clears the link and keeps the typed address when the address is not in the list" do
      update_user(user: { email: user.email, **typed_address(street_name: "Lessingstraße", street_number: "10") },
                  **not_in_list_params)

      user.reload
      expect(user.registered_address_id).to be_nil
      expect(user.street_name).to eq("Lessingstraße")
      expect(user.street_number).to eq("10")
    end

    it "ignores a registered address sent without a pick" do
      update_user(user: { email: user.email, registered_address_id: new_address.id, **typed_address })

      user.reload
      expect(user.registered_address_id).to eq(old_address.id)
      expect(user.street_name).to eq("Altstraße")
    end
  end

  describe "editing the own details in the account" do
    before do
      login_as(user)
      set_setting("extra_fields.registration.extended", true)
    end

    it "ignores a registered address sent without a pick" do
      patch update_details_account_path,
            params: { user: { registered_address_id: new_address.id, **typed_address }, **not_in_list_params }

      user.reload
      expect(user.registered_address_id).to be_nil
      expect(user.street_name).to eq("Altstraße")
    end

    it "links the picked address and copies it into the typed address" do
      patch update_details_account_path,
            params: { user: typed_address, **picker_params(new_address) }

      user.reload
      expect(user.registered_address_id).to eq(new_address.id)
      expect(user.street_name).to eq("Heidestraße")
    end
  end
end
