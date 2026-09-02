FactoryBot.define do
  factory :registered_address do
    sequence(:street_number, &:to_s)

    transient do
      street_name { "StreetName" }
      plz { "12345" }
      city_name { "CityName" }
    end

    after(:build) do |ra, evaluator|
      ra.registered_address_street = RegisteredAddress::Street.find_or_create_by!(
        name: evaluator.street_name, plz: evaluator.plz
      )
      ra.registered_address_city = RegisteredAddress::City.find_or_create_by!(name: evaluator.city_name)
    end
  end
end
