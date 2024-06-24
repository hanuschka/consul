FactoryBot.define do
  factory :registered_address, class: "RegisteredAddress" do
    sequence(:street_number, &:to_s)
    groupings do
      {
        "bezirk" => "1",
        "stadtteil" => "11",
        "schulbezirk" => "2"
      }
    end

    transient do
      street_name { "StreetName" }
      plz { "12345" }
      city_name { "CityName" }
    end

    after(:build) do |ra, evaluator|
      ra.registered_address_street = create(:registered_address_street, name: evaluator.street_name, plz: evaluator.plz)
      ra.registered_address_city = create(:registered_address_city, name: evaluator.city_name)
    end
  end

  factory :registered_address_street, class: "RegisteredAddress::Street" do
    name { "Street name" }
    plz { "12345" }
  end

  factory :registered_address_city, class: "RegisteredAddress::City" do
    name { "CityName" }
  end
end
